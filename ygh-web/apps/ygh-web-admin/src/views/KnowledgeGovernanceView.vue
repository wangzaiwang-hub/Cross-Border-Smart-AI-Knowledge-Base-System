<script setup lang="ts">
import { onMounted, ref } from "vue";
import { Refresh } from "@element-plus/icons-vue";
import { ElMessage } from "element-plus";
import {
    listAdminKnowledge,
    listIndexJobs,
    listProcessingJobs,
    retryIndexJob,
    retryProcessingJob,
    type KnowledgeDocument,
    type KnowledgeJob,
} from "@/api/operations";
const tab = ref("documents");
const loading = ref(true);
const documents = ref<KnowledgeDocument[]>([]);
const processing = ref<KnowledgeJob[]>([]);
const indexing = ref<KnowledgeJob[]>([]);
async function load() {
    loading.value = true;
    try {
        [documents.value, processing.value, indexing.value] = await Promise.all(
            [listAdminKnowledge(), listProcessingJobs(), listIndexJobs()],
        );
    } catch {
        ElMessage.error("知识治理数据加载失败");
    } finally {
        loading.value = false;
    }
}
async function retry(item: KnowledgeJob, type: "processing" | "index") {
    try {
        if (type === "processing") await retryProcessingJob(item.id);
        else await retryIndexJob(item.id);
        ElMessage.success("重试任务已受理");
        await load();
    } catch {
        ElMessage.error("任务重试失败");
    }
}
onMounted(load);
</script>
<template>
    <div class="page-head">
        <div>
            <h1>知识库治理</h1>
            <p>上传、安全校验、解析切片、审核、发布与索引版本的完整治理链。</p>
        </div>
        <el-button :icon="Refresh" @click="load">刷新</el-button>
    </div>
    <div class="metric-grid">
        <div class="metric panel">
            <span>文档总数</span><b>{{ documents.length }}</b>
        </div>
        <div class="metric panel">
            <span>待审核</span
            ><b>{{
                documents.filter((x) => x.status === "PENDING_REVIEW").length
            }}</b>
        </div>
        <div class="metric panel">
            <span>解析失败</span
            ><b>{{ processing.filter((x) => x.status === "FAILED").length }}</b>
        </div>
        <div class="metric panel">
            <span>索引失败</span
            ><b>{{ indexing.filter((x) => x.status === "FAILED").length }}</b>
        </div>
    </div>
    <el-tabs v-model="tab" v-loading="loading" class="panel governance"
        ><el-tab-pane label="全部知识" name="documents"
            ><el-table :data="documents"
                ><el-table-column prop="id" label="文档 ID" /><el-table-column
                    prop="title"
                    label="标题"
                    min-width="260"
                /><el-table-column
                    prop="category"
                    label="分类"
                /><el-table-column
                    prop="version"
                    label="版本"
                /><el-table-column prop="status" label="状态" /><el-table-column
                    label="更新时间"
                    ><template #default="scope">{{
                        new Date(scope.row.updatedAt).toLocaleString("zh-CN")
                    }}</template></el-table-column
                ></el-table
            ></el-tab-pane
        ><el-tab-pane label="解析任务" name="processing"
            ><el-table :data="processing"
                ><el-table-column prop="id" label="任务 ID" /><el-table-column
                    prop="documentId"
                    label="文档 ID"
                /><el-table-column
                    prop="taskType"
                    label="类型"
                /><el-table-column prop="status" label="状态" /><el-table-column
                    prop="progress"
                    label="进度"
                /><el-table-column
                    prop="failureReason"
                    label="失败原因"
                /><el-table-column label="操作"
                    ><template #default="scope"
                        ><el-button
                            v-if="scope.row.status === 'FAILED'"
                            link
                            type="danger"
                            @click="retry(scope.row, 'processing')"
                            >重试</el-button
                        ></template
                    ></el-table-column
                ></el-table
            ></el-tab-pane
        ><el-tab-pane label="索引任务" name="index"
            ><el-table :data="indexing"
                ><el-table-column prop="id" label="任务 ID" /><el-table-column
                    prop="documentId"
                    label="文档 ID"
                /><el-table-column
                    prop="indexVersion"
                    label="索引版本"
                /><el-table-column prop="status" label="状态" /><el-table-column
                    prop="failureReason"
                    label="失败原因"
                /><el-table-column label="操作"
                    ><template #default="scope"
                        ><el-button
                            v-if="scope.row.status === 'FAILED'"
                            link
                            type="danger"
                            @click="retry(scope.row, 'index')"
                            >重试</el-button
                        ></template
                    ></el-table-column
                ></el-table
            ></el-tab-pane
        ></el-tabs
    >
</template>
<style scoped>
.governance {
    margin-top: 14px;
    padding: 16px;
}
</style>
