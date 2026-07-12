<script setup lang="ts">
import { computed, onMounted, ref } from "vue";
import { Search, Reading } from "@element-plus/icons-vue";
import { ElMessage } from "element-plus";
import PageHeader from "@/components/PageHeader.vue";
import { listKnowledge, type KnowledgeDocument } from "@/api/knowledge";
const keyword = ref("");
const category = ref("");
const loading = ref(true);
const documents = ref<KnowledgeDocument[]>([]);
const categories = ["政策法规", "通关流程", "商品知识"];
const list = computed(() =>
    documents.value.filter(
        (document) =>
            (!category.value || document.category === category.value) &&
            (document.title + document.fileName)
                .toLowerCase()
                .includes(keyword.value.toLowerCase()),
    ),
);
async function load() {
    loading.value = true;
    try {
        documents.value = await listKnowledge(category.value);
    } catch {
        ElMessage.error("知识目录加载失败");
    } finally {
        loading.value = false;
    }
}
onMounted(load);
</script>
<template>
    <div class="knowledge-hero">
        <div class="container">
            <span class="section-label">ENTERPRISE KNOWLEDGE BASE</span>
            <h1 class="serif">跨境知识，有版本、有审核、有出处。</h1>
            <p>
                聚合商品知识、政策法规与通关流程。只有审核发布且在有效期内的内容进入检索与
                AI 问答。
            </p>
            <el-input
                v-model="keyword"
                size="large"
                :prefix-icon="Search"
                placeholder="搜索政策名称、通关环节、商品知识……"
                clearable
            />
        </div>
    </div>
    <div class="page-shell">
        <div class="container knowledge-layout">
            <aside class="paper-card">
                <b>知识分类</b
                ><button
                    :class="{ active: !category }"
                    @click="
                        category = '';
                        load();
                    "
                >
                    全部<span>{{ documents.length }}</span></button
                ><button
                    v-for="c in categories"
                    :key="c"
                    :class="{ active: category === c }"
                    @click="
                        category = c;
                        load();
                    "
                >
                    {{ c }}
                </button>
                <div class="ai-entry">
                    <el-icon><Reading /></el-icon><b>找不到答案？</b>
                    <p>让 AI 在已发布知识中检索并标注引用。</p>
                    <el-button
                        type="primary"
                        size="small"
                        @click="$router.push('/ai-service')"
                        >咨询 AI</el-button
                    >
                </div>
            </aside>
            <main v-loading="loading">
                <PageHeader
                    eyebrow="PUBLISHED KNOWLEDGE"
                    :title="category || '全部已发布知识'"
                    :description="`共 ${list.length} 条有效内容，按最近更新排序`"
                /><el-empty
                    v-if="!loading && !list.length"
                    description="没有符合条件的已发布知识"
                />
                <div class="article-list">
                    <RouterLink
                        v-for="article in list"
                        :key="article.id"
                        :to="`/knowledge/${article.id}`"
                        ><div class="article-mark">
                            {{ article.category.slice(0, 1) }}
                        </div>
                        <div>
                            <div class="meta">
                                <el-tag size="small" effect="plain">{{
                                    article.category
                                }}</el-tag
                                ><span>版本 {{ article.version }}</span
                                ><span>{{ article.mediaType }}</span>
                            </div>
                            <h2 class="serif">{{ article.title }}</h2>
                            <p>
                                来源文件：{{ article.fileName }} · 校验摘要
                                {{ article.sha256.slice(0, 12) }}…
                            </p>
                            <small
                                >更新于
                                {{
                                    new Date(article.updatedAt).toLocaleString(
                                        "zh-CN",
                                    )
                                }}
                                · 已审核发布</small
                            >
                        </div></RouterLink
                    >
                </div>
            </main>
        </div>
    </div>
</template>
<style scoped>
.knowledge-hero {
    padding: 70px 0;
    background: linear-gradient(120deg, #083d39, #0c5b54);
    color: #fff;
}
.knowledge-hero h1 {
    margin: 12px 0;
    font-size: 43px;
}
.knowledge-hero p {
    color: #b7cbc5;
}
.knowledge-hero .el-input {
    width: min(680px, 100%);
    margin-top: 22px;
}
.knowledge-layout {
    display: grid;
    grid-template-columns: 230px 1fr;
    gap: 34px;
}
.knowledge-layout aside {
    height: max-content;
    padding: 20px;
    position: sticky;
    top: 120px;
}
.knowledge-layout aside > b {
    display: block;
    margin: 5px 8px 14px;
}
.knowledge-layout aside > button {
    width: 100%;
    display: flex;
    justify-content: space-between;
    padding: 10px 12px;
    border: 0;
    border-radius: 7px;
    background: transparent;
    color: var(--muted);
    cursor: pointer;
}
.knowledge-layout aside > button.active {
    background: var(--jade-soft);
    color: var(--jade);
    font-weight: 700;
}
.ai-entry {
    margin-top: 22px;
    padding: 18px;
    background: #f1ecdf;
    border-top: 3px solid var(--gold);
}
.ai-entry .el-icon {
    color: var(--cinnabar);
    font-size: 24px;
}
.ai-entry b {
    display: block;
    margin-top: 8px;
}
.ai-entry p {
    color: var(--muted);
    font-size: 12px;
    line-height: 1.7;
}
.article-list {
    display: grid;
    gap: 12px;
}
.article-list > a {
    display: grid;
    grid-template-columns: 55px 1fr;
    gap: 18px;
    padding: 22px;
    background: #fff;
    border: 1px solid var(--line);
}
.article-mark {
    width: 52px;
    height: 58px;
    display: grid;
    place-items: center;
    background: var(--jade);
    color: #fff;
    font: 700 24px serif;
}
.meta {
    display: flex;
    gap: 13px;
    color: var(--muted);
    font-size: 11px;
}
.article-list h2 {
    margin: 10px 0 7px;
    font-size: 19px;
}
.article-list p,
.article-list small {
    color: var(--muted);
}
@media (max-width: 750px) {
    .knowledge-layout {
        grid-template-columns: 1fr;
    }
    .knowledge-layout aside {
        position: static;
    }
}
</style>
