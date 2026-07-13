<script setup lang="ts">
import { onMounted, reactive, ref } from "vue";
import { Refresh } from "@element-plus/icons-vue";
import { ElMessage, ElMessageBox, type UploadFile } from "element-plus";
import {
    listAdminKnowledge,
    listIndexJobs,
    listProcessingJobs,
    offlineKnowledge,
    reviewKnowledge,
    retryIndexJob,
    retryProcessingJob,
    rebuildKnowledgeIndex,
    uploadKnowledge,
    type KnowledgeDocument,
    type KnowledgeJob,
} from "@/api/operations";
import EnterpriseTable from "@/components/EnterpriseTable.vue";
const tab = ref("documents");
const loading = ref(true);
const documents = ref<KnowledgeDocument[]>([]);
const processing = ref<KnowledgeJob[]>([]);
const indexing = ref<KnowledgeJob[]>([]);
const uploadDialog = ref(false);
const uploading = ref(false);
const rebuilding = ref(false);
const file = ref<File>();
const form = reactive({ title: "", category: "政策法规" });
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
function selectFile(item: UploadFile) {
    file.value = item.raw;
}
async function upload() {
    if (!file.value || !form.title.trim())
        return ElMessage.warning("请填写标题并选择文件");
    uploading.value = true;
    try {
        await uploadKnowledge(form.title, form.category, file.value);
        uploadDialog.value = false;
        ElMessage.success("文件已进入安全处理流程");
        await load();
    } catch {
        ElMessage.error("上传失败，请检查文件类型和大小");
    } finally {
        uploading.value = false;
    }
}
async function review(
    document: KnowledgeDocument,
    decision: "APPROVE" | "REJECT",
) {
    const { value } = await ElMessageBox.prompt(
        decision === "APPROVE" ? "请输入审核意见" : "请输入驳回原因",
        "知识审核",
        { inputValidator: (value) => Boolean(value?.trim()) || "意见不能为空" },
    );
    try {
        await reviewKnowledge(document, decision, value);
        ElMessage.success("审核结果已保存");
        await load();
    } catch {
        ElMessage.error("审核失败，状态或版本可能已变化");
    }
}
async function offline(document: KnowledgeDocument) {
    const { value } = await ElMessageBox.prompt("请输入下线原因", "知识下线", {
        inputValidator: (value) => Boolean(value?.trim()) || "原因不能为空",
    });
    try {
        await offlineKnowledge(document, value);
        ElMessage.success("知识已下线");
        await load();
    } catch {
        ElMessage.error("下线失败");
    }
}
async function rebuild() {
    const defaultVersion = `knowledge-v${new Date()
        .toISOString()
        .replace(/[-:TZ.]/g, "")}`;
    const { value } = await ElMessageBox.prompt(
        "系统将从已发布且未过期的知识重新生成索引任务。旧索引在完成校验和版本切换前仍然可用。",
        "创建全量索引版本",
        {
            inputValue: defaultVersion,
            inputPattern: /^[a-z0-9][a-z0-9._-]{1,63}$/,
            inputErrorMessage: "版本只能使用小写字母、数字、点、下划线和连字符",
            confirmButtonText: "确认创建",
        },
    );
    rebuilding.value = true;
    try {
        const result = await rebuildKnowledgeIndex(value);
        ElMessage.success(`已为 ${result.queuedDocuments} 篇知识创建重建任务`);
        tab.value = "index";
        await load();
    } catch {
        ElMessage.error("索引重建任务创建失败");
    } finally {
        rebuilding.value = false;
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
        <div>
            <el-button :loading="rebuilding" @click="rebuild"
                >全量重建索引</el-button
            >
            <el-button type="primary" @click="uploadDialog = true"
                >上传知识</el-button
            ><el-button :icon="Refresh" @click="load">刷新</el-button>
        </div>
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
            ><EnterpriseTable
                :items="documents"
                :search-fields="['id', 'title', 'category', 'version']"
                status-field="status"
                search-placeholder="检索文档 ID、标题、分类或版本"
                v-slot="{ rows, emptyText }"
            ><el-table :data="rows" :empty-text="emptyText"
                ><el-table-column prop="id" label="文档 ID" /><el-table-column
                    prop="title"
                    label="标题"
                    min-width="250"
                /><el-table-column
                    prop="category"
                    label="分类"
                /><el-table-column
                    prop="version"
                    label="版本"
                /><el-table-column prop="status" label="状态" /><el-table-column
                    label="操作"
                    width="180"
                    ><template #default="scope"
                        ><el-button
                            v-if="scope.row.status === 'PENDING_REVIEW'"
                            link
                            type="primary"
                            @click="review(scope.row, 'APPROVE')"
                            >通过</el-button
                        ><el-button
                            v-if="scope.row.status === 'PENDING_REVIEW'"
                            link
                            type="danger"
                            @click="review(scope.row, 'REJECT')"
                            >驳回</el-button
                        ><el-button
                            v-if="scope.row.status === 'PUBLISHED'"
                            link
                            type="warning"
                            @click="offline(scope.row)"
                            >下线</el-button
                        ></template
                    ></el-table-column
                ></el-table></EnterpriseTable
            ></el-tab-pane
        ><el-tab-pane label="解析任务" name="processing"
            ><EnterpriseTable
                :items="processing"
                :search-fields="['id', 'documentId', 'taskType', 'failureReason']"
                status-field="status"
                search-placeholder="检索任务、文档、类型或失败原因"
                v-slot="{ rows, emptyText }"
            ><el-table :data="rows" :empty-text="emptyText"
                ><el-table-column prop="id" label="任务 ID" /><el-table-column
                    prop="documentId"
                    label="文档 ID"
                /><el-table-column
                    prop="taskType"
                    label="类型"
                /><el-table-column prop="status" label="状态" /><el-table-column
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
                ></el-table></EnterpriseTable
            ></el-tab-pane
        ><el-tab-pane label="索引任务" name="index"
            ><EnterpriseTable
                :items="indexing"
                :search-fields="['id', 'documentId', 'indexVersion', 'failureReason']"
                status-field="status"
                search-placeholder="检索任务、文档、索引版本或失败原因"
                v-slot="{ rows, emptyText }"
            ><el-table :data="rows" :empty-text="emptyText"
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
                ></el-table></EnterpriseTable
            ></el-tab-pane
        ></el-tabs
    ><el-dialog v-model="uploadDialog" title="上传知识文档" width="520"
        ><el-form label-position="top"
            ><el-form-item label="标题"
                ><el-input
                    v-model="form.title"
                    maxlength="200"
                    show-word-limit /></el-form-item
            ><el-form-item label="分类"
                ><el-select v-model="form.category" style="width: 100%"
                    ><el-option
                        v-for="item in ['政策法规', '通关流程', '商品知识']"
                        :key="item"
                        :label="item"
                        :value="item" /></el-select></el-form-item
            ><el-form-item label="文件"
                ><el-upload
                    :auto-upload="false"
                    :limit="1"
                    accept=".pdf,.docx,.txt,.md"
                    @change="selectFile"
                    ><el-button>选择文件</el-button></el-upload
                ></el-form-item
            ></el-form
        ><template #footer
            ><el-button @click="uploadDialog = false">取消</el-button
            ><el-button type="primary" :loading="uploading" @click="upload"
                >上传并处理</el-button
            ></template
        ></el-dialog
    >
</template>
<style scoped>
.governance {
    margin-top: 14px;
    padding: 16px;
}
</style>
