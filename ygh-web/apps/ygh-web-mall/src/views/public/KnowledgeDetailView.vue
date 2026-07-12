<script setup lang="ts">
import { onMounted, ref } from "vue";
import { useRoute } from "vue-router";
import { ElMessage } from "element-plus";
import {
    getKnowledge,
    getKnowledgeMetadata,
    type KnowledgeDocument,
    type KnowledgeMetadata,
} from "@/api/knowledge";
const route = useRoute();
const loading = ref(true);
const article = ref<KnowledgeDocument>();
const metadata = ref<KnowledgeMetadata>();
onMounted(async () => {
    try {
        [article.value, metadata.value] = await Promise.all([
            getKnowledge(String(route.params.id)),
            getKnowledgeMetadata(String(route.params.id)),
        ]);
    } catch {
        ElMessage.error("知识文档加载失败");
    } finally {
        loading.value = false;
    }
});
</script>
<template>
    <div v-loading="loading" class="page-shell">
        <div class="container article-layout">
            <article class="paper-card article">
                <el-breadcrumb separator="/"
                    ><el-breadcrumb-item to="/knowledge"
                        >知识中心</el-breadcrumb-item
                    ><el-breadcrumb-item>{{
                        article?.category
                    }}</el-breadcrumb-item></el-breadcrumb
                >
                <header>
                    <el-tag effect="plain">{{ article?.category }}</el-tag>
                    <h1 class="serif">{{ article?.title }}</h1>
                    <div>
                        {{
                            metadata?.issuingAuthority ||
                            metadata?.sourceName ||
                            "企业知识库"
                        }}
                        · 更新于
                        {{
                            article
                                ? new Date(article.updatedAt).toLocaleString(
                                      "zh-CN",
                                  )
                                : ""
                        }}
                        · 当前版本 {{ article?.version }}
                    </div>
                </header>
                <el-alert
                    title="发布状态：有效"
                    type="success"
                    show-icon
                    :closable="false"
                    description="本文已通过审核并进入全文与向量检索索引。引用时请以当前版本为准。"
                />
                <section>
                    <h2>文档档案</h2>
                    <el-descriptions :column="2" border
                        ><el-descriptions-item label="文件名">{{
                            article?.fileName
                        }}</el-descriptions-item
                        ><el-descriptions-item label="媒体类型">{{
                            article?.mediaType
                        }}</el-descriptions-item
                        ><el-descriptions-item label="发布机构">{{
                            metadata?.issuingAuthority || "--"
                        }}</el-descriptions-item
                        ><el-descriptions-item label="适用地区">{{
                            metadata?.region || "--"
                        }}</el-descriptions-item
                        ><el-descriptions-item label="生效日期">{{
                            metadata?.effectiveFrom || "--"
                        }}</el-descriptions-item
                        ><el-descriptions-item label="失效时间">{{
                            metadata?.expiresAt || "长期有效"
                        }}</el-descriptions-item
                        ><el-descriptions-item label="密级">{{
                            metadata?.classification
                        }}</el-descriptions-item
                        ><el-descriptions-item label="来源">{{
                            metadata?.sourceName || "--"
                        }}</el-descriptions-item></el-descriptions
                    >
                    <h2>内容使用说明</h2>
                    <p>
                        知识正文由受控附件服务保存。本页面只展示后端确认的文档档案，不根据标题虚构政策条款。需要查询具体内容时，可使用
                        AI 客服基于已发布切片检索并返回引用。
                    </p>
                    <blockquote>
                        未审核、已驳回、已下线、失效或超出当前用户权限的知识不会进入有效检索结果。
                    </blockquote>
                </section>
            </article>
            <aside>
                <div class="paper-card toc">
                    <b>文档标签</b
                    ><el-tag
                        v-for="tag in metadata?.tags || []"
                        :key="tag"
                        effect="plain"
                        >{{ tag }}</el-tag
                    ><span v-if="!metadata?.tags?.length">暂无标签</span>
                </div>
                <div class="paper-card ask">
                    <b>需要结合业务提问？</b>
                    <p>AI 客服会在回答中附上知识引用。</p>
                    <el-button
                        type="primary"
                        @click="
                            $router.push({
                                path: '/ai-service',
                                query: { q: article?.title },
                            })
                        "
                        >基于本文提问</el-button
                    >
                </div>
            </aside>
        </div>
    </div>
</template>
<style scoped>
.article-layout {
    display: grid;
    grid-template-columns: minmax(0, 1fr) 260px;
    gap: 26px;
}
.article {
    padding: 36px 44px;
}
.article header {
    padding: 28px 0;
    border-bottom: 1px solid var(--line);
    margin-bottom: 20px;
}
.article h1 {
    margin: 14px 0;
    font-size: 36px;
}
.article header div {
    color: var(--muted);
    font-size: 13px;
}
.article section {
    font-size: 15px;
    line-height: 2;
}
.article section h2 {
    margin-top: 38px;
    font: 700 22px serif;
}
.article blockquote {
    margin: 25px 0 0;
    padding: 18px 22px;
    background: #f3eee2;
    border-left: 4px solid var(--cinnabar);
}
aside > div {
    padding: 22px;
    margin-bottom: 18px;
}
.toc {
    display: flex;
    flex-direction: column;
    align-items: start;
    gap: 10px;
}
.ask {
    background: var(--jade-dark);
    color: white;
}
.ask p {
    color: #aac1bb;
    font-size: 13px;
    line-height: 1.7;
}
@media (max-width: 800px) {
    .article-layout {
        grid-template-columns: 1fr;
    }
    .article {
        padding: 24px;
    }
}
</style>
