// supabase/functions/generate-ai-item/index.ts
//
// AI 物品生成 Edge Function
// 调用阿里云百炼 qwen-flash 模型生成独特物品

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import OpenAI from "npm:openai";

// 阿里云百炼配置（新加坡国际版端点）
const openai = new OpenAI({
    apiKey: Deno.env.get("DASHSCOPE_API_KEY"),
    baseURL: "https://dashscope-intl.aliyuncs.com/compatible-mode/v1"
});

// 请求参数接口
interface GenerateItemRequest {
    poi_name: string;           // POI 名称
    poi_category: string;       // POI 类别
    danger_level: number;       // 危险等级 (1-5)
    item_count: number;         // 生成物品数量
}

// AI 生成的物品接口
interface GeneratedItem {
    unique_name: string;        // 独特名称
    base_category: string;      // 基础分类
    rarity: string;             // 稀有度
    backstory: string;          // 背景故事
    quantity: number;           // 数量
}

// 响应接口
interface GenerateItemResponse {
    items: GeneratedItem[];
    error?: string;
}

// 根据危险值获取稀有度分布
function getRarityDistribution(dangerLevel: number): Record<string, number> {
    switch (dangerLevel) {
        case 1:
        case 2:
            return { common: 0.70, uncommon: 0.25, rare: 0.05, epic: 0, legendary: 0 };
        case 3:
            return { common: 0.50, uncommon: 0.30, rare: 0.15, epic: 0.05, legendary: 0 };
        case 4:
            return { common: 0, uncommon: 0.40, rare: 0.35, epic: 0.20, legendary: 0.05 };
        case 5:
            return { common: 0, uncommon: 0, rare: 0.30, epic: 0.40, legendary: 0.30 };
        default:
            return { common: 0.70, uncommon: 0.25, rare: 0.05, epic: 0, legendary: 0 };
    }
}

// 根据概率分布选择稀有度
function selectRarity(distribution: Record<string, number>): string {
    const rand = Math.random();
    let cumulative = 0;
    for (const [rarity, prob] of Object.entries(distribution)) {
        cumulative += prob;
        if (rand <= cumulative) {
            return rarity;
        }
    }
    return "common";
}

// 稀有度中文映射
const rarityNames: Record<string, string> = {
    common: "普通",
    uncommon: "罕见",
    rare: "稀有",
    epic: "史诗",
    legendary: "传说"
};

// 系统提示词
const SYSTEM_PROMPT = `你是一个末日生存游戏的物品生成器。游戏背景是末日废土世界，玩家在废墟中搜刮物资。

你的任务是根据给定的地点信息，生成具有独特名称和背景故事的物品。

物品分类必须是以下之一：
- 水源：饮用水相关
- 食物：食品相关
- 医疗：医药用品
- 材料：建筑/制作材料
- 工具：各类工具

生成规则：
1. 独特名称应结合地点特征，有末日风格（如"老王的最后存货"、"锈迹斑斑的急救箱"），15字以内
2. 背景故事要简短有画面感（30-50字），营造末日氛围，可以有黑色幽默
3. 稀有度越高，名称越独特，故事越有深度和情感
4. 物品应与地点类型相关（超市出食物，医院出医疗用品等）

你必须严格按照JSON数组格式输出，不要输出其他内容。`;

// 降级：生成默认物品
function generateFallbackItems(category: string, count: number, rarities: string[]): GeneratedItem[] {
    const categoryMap: Record<string, { name: string; baseCategory: string; story: string }[]> = {
        "超市": [
            { name: "罐头食品", baseCategory: "食物", story: "货架深处找到的罐头，保质期还没过。" },
            { name: "瓶装水", baseCategory: "水源", story: "收银台下的矿泉水，还算干净。" },
            { name: "废弃纸箱", baseCategory: "材料", story: "可以拆解利用的包装材料。" },
        ],
        "医院": [
            { name: "医用绷带", baseCategory: "医疗", story: "急诊室抽屉里的医疗用品。" },
            { name: "止痛片", baseCategory: "医疗", story: "药房残留的基础药物。" },
            { name: "手术刀", baseCategory: "工具", story: "锋利但需要清洁的医疗器械。" },
        ],
        "药店": [
            { name: "常规药品", baseCategory: "医疗", story: "柜台后面找到的常用药。" },
            { name: "急救包", baseCategory: "医疗", story: "还算完整的急救套装。" },
        ],
        "加油站": [
            { name: "工具零件", baseCategory: "工具", story: "维修区遗留的工具。" },
            { name: "便利店食品", baseCategory: "食物", story: "便利店货架上的零食。" },
        ],
        "便利店": [
            { name: "零食", baseCategory: "食物", story: "货架角落的小食品。" },
            { name: "饮料", baseCategory: "水源", story: "冰柜里已经不冰的饮料。" },
        ],
        "餐厅": [
            { name: "剩余食材", baseCategory: "食物", story: "厨房里还能用的食材。" },
            { name: "餐具", baseCategory: "工具", story: "还算干净的餐具。" },
        ],
        "咖啡店": [
            { name: "咖啡豆", baseCategory: "食物", story: "密封保存的咖啡豆。" },
            { name: "瓶装水", baseCategory: "水源", story: "柜台下的饮用水。" },
        ],
        "商店": [
            { name: "杂货", baseCategory: "材料", story: "各种各样的杂物。" },
            { name: "工具", baseCategory: "工具", story: "货架上的基础工具。" },
        ],
    };

    const items = categoryMap[category] || [
        { name: "废墟杂物", baseCategory: "材料", story: "在废墟中发现的物资。" },
    ];

    const result: GeneratedItem[] = [];
    for (let i = 0; i < count; i++) {
        const item = items[i % items.length];
        const rarity = rarities[i] || "common";
        result.push({
            unique_name: item.name,
            base_category: item.baseCategory,
            rarity: rarityNames[rarity] || "普通",
            backstory: item.story,
            quantity: Math.floor(Math.random() * 3) + 1,
        });
    }
    return result;
}

Deno.serve(async (req) => {
    // 处理 CORS
    if (req.method === "OPTIONS") {
        return new Response(null, {
            headers: {
                "Access-Control-Allow-Origin": "*",
                "Access-Control-Allow-Methods": "POST, OPTIONS",
                "Access-Control-Allow-Headers": "Content-Type, Authorization",
            },
        });
    }

    try {
        const request: GenerateItemRequest = await req.json();
        const { poi_name, poi_category, danger_level, item_count } = request;

        console.log(`[generate-ai-item] 收到请求: ${poi_name}, 类型: ${poi_category}, 危险等级: ${danger_level}, 数量: ${item_count}`);

        // 验证参数
        if (!poi_name || !poi_category || !danger_level || !item_count) {
            return new Response(
                JSON.stringify({ items: [], error: "Missing required parameters" }),
                { status: 400, headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" } }
            );
        }

        // 获取稀有度分布
        const rarityDist = getRarityDistribution(danger_level);

        // 为每个物品预选稀有度
        const rarities: string[] = [];
        for (let i = 0; i < item_count; i++) {
            rarities.push(selectRarity(rarityDist));
        }

        const rarityChinese = rarities.map(r => rarityNames[r]);
        console.log(`[generate-ai-item] 预选稀有度: ${rarityChinese.join(", ")}`);

        // 构建用户提示
        const userPrompt = `地点名称：${poi_name}
地点类型：${poi_category}
危险等级：${danger_level}/5

请生成 ${item_count} 个物品，稀有度分别为：${rarityChinese.join("、")}

返回JSON数组格式，每个物品包含：
- unique_name: 独特名称（15字以内）
- base_category: 基础分类（水源/食物/医疗/材料/工具）
- rarity: 稀有度（使用给定的稀有度）
- backstory: 背景故事（30-50字）
- quantity: 数量（1-3）`;

        // 调用 qwen-flash
        const completion = await openai.chat.completions.create({
            model: "qwen-plus",
            messages: [
                { role: "system", content: SYSTEM_PROMPT },
                { role: "user", content: userPrompt }
            ],
            temperature: 0.8,
            max_tokens: 1000,
        });

        const content = completion.choices[0]?.message?.content || "[]";
        console.log(`[generate-ai-item] AI 响应: ${content.substring(0, 200)}...`);

        // 解析 AI 响应
        let items: GeneratedItem[];
        try {
            // 尝试提取 JSON 数组
            const jsonMatch = content.match(/\[[\s\S]*\]/);
            if (jsonMatch) {
                items = JSON.parse(jsonMatch[0]);
                // 验证并修正数据
                items = items.map((item, index) => ({
                    unique_name: item.unique_name || "未知物品",
                    base_category: item.base_category || "材料",
                    rarity: item.rarity || rarityChinese[index] || "普通",
                    backstory: item.backstory || "在废墟中发现的物资。",
                    quantity: item.quantity || Math.floor(Math.random() * 3) + 1,
                }));
            } else {
                throw new Error("No JSON array found in response");
            }
        } catch (parseError) {
            console.error(`[generate-ai-item] JSON 解析错误: ${parseError}`);
            // 返回降级响应
            items = generateFallbackItems(poi_category, item_count, rarities);
        }

        // 确保返回正确数量的物品
        if (items.length < item_count) {
            const fallback = generateFallbackItems(poi_category, item_count - items.length, rarities.slice(items.length));
            items = [...items, ...fallback];
        }

        console.log(`[generate-ai-item] 成功生成 ${items.length} 个物品`);

        const response: GenerateItemResponse = { items };

        return new Response(JSON.stringify(response), {
            headers: {
                "Content-Type": "application/json",
                "Access-Control-Allow-Origin": "*",
            },
        });

    } catch (error) {
        console.error(`[generate-ai-item] 错误: ${error}`);
        return new Response(
            JSON.stringify({ items: [], error: error.message }),
            {
                status: 500,
                headers: {
                    "Content-Type": "application/json",
                    "Access-Control-Allow-Origin": "*",
                }
            }
        );
    }
});
