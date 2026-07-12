<script setup lang="ts">
import { onMounted, reactive, ref } from "vue";
import { ElMessage } from "element-plus";
import {
    getAiSummary,
    createPrompt,
    createEvaluationCase,
    listEvaluationCases,
    listPrompts,
    runAiEvaluations,
    type AiSummary,
    type EvaluationCase,
    type EvaluationRun,
    type PromptConfig,
} from "@/api/operations";
const tab = ref("prompt");
const loading = ref(true);
const running = ref(false);
const prompts = ref<PromptConfig[]>([]);
const cases = ref<EvaluationCase[]>([]);
const summary = ref<AiSummary>();
const runs = ref<EvaluationRun[]>([]);
const promptDialog = ref(false);
const caseDialog = ref(false);
const saving = ref(false);
const promptForm = reactive({
    code: "CUSTOMS_ASSISTANT",
    systemPrompt: "",
    modelName: "doubao-pro-32k",
    temperature: 0.2,
    knowledgeScope: "POLICY,CUSTOMS,PRODUCT",
    sensitiveWords: "",
    enabled: true,
    version: 0,
});
const caseForm = reactive({
    category: "POLICY",
    question: "",
    expectedEvidence: "",
    forbiddenAnswer: "",
    enabled: true,
});
async function load() {
    loading.value = true;
    try {
        [prompts.value, cases.value, summary.value] = await Promise.all([
            listPrompts(),
            listEvaluationCases(),
            getAiSummary(),
        ]);
    } catch {
        ElMessage.error("AI 治理数据加载失败");
    } finally {
        loading.value = false;
    }
}
async function run() {
    running.value = true;
    try {
        runs.value = await runAiEvaluations();
        ElMessage.success("离线评测完成");
    } catch {
        ElMessage.error("离线评测失败");
    } finally {
        running.value = false;
    }
}
async function savePrompt() {
    saving.value = true;
    try {
        await createPrompt(promptForm);
        promptDialog.value = false;
        ElMessage.success("提示词新版本已保存");
        await load();
    } catch {
        ElMessage.error("提示词保存失败，请检查编码与字段长度");
    } finally {
        saving.value = false;
    }
}
async function saveCase() {
    saving.value = true;
    try {
        await createEvaluationCase(caseForm);
        caseDialog.value = false;
        ElMessage.success("评测用例已新增");
        await load();
    } catch {
        ElMessage.error("评测用例保存失败");
    } finally {
        saving.value = false;
    }
}
onMounted(load);
</script>
<template>
    <div v-loading="loading">
        <div class="page-head">
            <div>
                <h1>AI 客服治理</h1>
                <p>管理提示词版本、评测集与离线评测结果。</p>
            </div>
            <div>
                <el-button @click="caseDialog = true">新增评测用例</el-button
                ><el-button type="primary" @click="promptDialog = true"
                    >新建提示词版本</el-button
                ><el-tag :type="summary?.activePrompt ? 'success' : 'danger'">{{
                    summary?.activePrompt ? "存在启用提示词" : "无启用提示词"
                }}</el-tag>
            </div>
        </div>
        <div class="metric-grid">
            <div class="metric panel">
                <span>会话</span><b>{{ summary?.conversations || 0 }}</b>
            </div>
            <div class="metric panel">
                <span>消息</span><b>{{ summary?.messages || 0 }}</b>
            </div>
            <div class="metric panel">
                <span>拒答</span><b>{{ summary?.refusals || 0 }}</b>
            </div>
            <div class="metric panel">
                <span>有效评测用例</span
                ><b>{{ summary?.enabledEvaluationCases || 0 }}</b>
            </div>
        </div>
        <el-tabs v-model="tab" class="panel ai-config"
            ><el-tab-pane label="提示词版本" name="prompt"
                ><el-table :data="prompts"
                    ><el-table-column
                        prop="code"
                        label="编码"
                    /><el-table-column
                        prop="modelName"
                        label="模型"
                    /><el-table-column
                        prop="temperature"
                        label="温度"
                    /><el-table-column
                        prop="knowledgeScope"
                        label="知识范围"
                    /><el-table-column
                        prop="version"
                        label="版本"
                    /><el-table-column label="状态"
                        ><template #default="scope"
                            ><el-tag
                                :type="scope.row.enabled ? 'success' : 'info'"
                                >{{
                                    scope.row.enabled ? "启用" : "停用"
                                }}</el-tag
                            ></template
                        ></el-table-column
                    ></el-table
                ></el-tab-pane
            ><el-tab-pane label="评测集" name="evaluation"
                ><el-table :data="cases"
                    ><el-table-column
                        prop="category"
                        label="分类"
                    /><el-table-column
                        prop="question"
                        label="问题"
                        min-width="280"
                    /><el-table-column
                        prop="expectedEvidence"
                        label="预期证据"
                        min-width="240"
                    /><el-table-column label="状态"
                        ><template #default="scope"
                            ><el-tag>{{
                                scope.row.enabled ? "启用" : "停用"
                            }}</el-tag></template
                        ></el-table-column
                    ></el-table
                ><el-button
                    type="primary"
                    :loading="running"
                    style="margin-top: 15px"
                    @click="run"
                    >运行全量评测</el-button
                ></el-tab-pane
            ><el-tab-pane label="最近运行" name="runs"
                ><el-table :data="runs"
                    ><el-table-column
                        prop="caseId"
                        label="用例 ID" /><el-table-column
                        prop="score"
                        label="得分" /><el-table-column
                        prop="citationCount"
                        label="引用数" /><el-table-column
                        prop="durationMs"
                        label="耗时 ms" /><el-table-column label="结果"
                        ><template #default="scope"
                            ><el-tag
                                :type="scope.row.passed ? 'success' : 'danger'"
                                >{{
                                    scope.row.passed ? "通过" : "失败"
                                }}</el-tag
                            ></template
                        ></el-table-column
                    ><el-table-column
                        prop="failureReason"
                        label="失败原因" /></el-table></el-tab-pane></el-tabs
        ><el-dialog v-model="promptDialog" title="新建提示词版本" width="700"
            ><el-form label-position="top"
                ><div class="form-grid">
                    <el-form-item label="配置编码"
                        ><el-input v-model="promptForm.code" /></el-form-item
                    ><el-form-item label="模型名称"
                        ><el-input v-model="promptForm.modelName"
                    /></el-form-item>
                </div>
                <el-form-item label="系统提示词"
                    ><el-input
                        v-model="promptForm.systemPrompt"
                        type="textarea"
                        :rows="8"
                        maxlength="12000"
                        show-word-limit
                /></el-form-item>
                <div class="form-grid">
                    <el-form-item label="温度"
                        ><el-input-number
                            v-model="promptForm.temperature"
                            :min="0"
                            :max="2"
                            :step="0.1" /></el-form-item
                    ><el-form-item label="启用"
                        ><el-switch v-model="promptForm.enabled"
                    /></el-form-item>
                </div>
                <el-form-item label="知识范围"
                    ><el-input
                        v-model="promptForm.knowledgeScope" /></el-form-item
                ><el-form-item label="敏感词规则"
                    ><el-input
                        v-model="promptForm.sensitiveWords"
                        type="textarea" /></el-form-item></el-form
            ><template #footer
                ><el-button @click="promptDialog = false">取消</el-button
                ><el-button type="primary" :loading="saving" @click="savePrompt"
                    >保存版本</el-button
                ></template
            ></el-dialog
        ><el-dialog v-model="caseDialog" title="新增离线评测用例" width="620"
            ><el-form label-position="top"
                ><el-form-item label="分类"
                    ><el-select v-model="caseForm.category" style="width: 100%"
                        ><el-option
                            v-for="value in [
                                'POLICY',
                                'CUSTOMS',
                                'TRACEABILITY',
                                'RECOMMENDATION',
                            ]"
                            :key="value"
                            :label="value"
                            :value="value" /></el-select></el-form-item
                ><el-form-item label="问题"
                    ><el-input
                        v-model="caseForm.question"
                        type="textarea" /></el-form-item
                ><el-form-item label="预期证据"
                    ><el-input
                        v-model="caseForm.expectedEvidence"
                        type="textarea" /></el-form-item
                ><el-form-item label="禁止回答"
                    ><el-input
                        v-model="caseForm.forbiddenAnswer"
                        type="textarea" /></el-form-item
                ><el-form-item label="启用"
                    ><el-switch
                        v-model="caseForm.enabled" /></el-form-item></el-form
            ><template #footer
                ><el-button @click="caseDialog = false">取消</el-button
                ><el-button type="primary" :loading="saving" @click="saveCase"
                    >保存用例</el-button
                ></template
            ></el-dialog
        >
    </div>
</template>
<style scoped>
.ai-config {
    margin-top: 14px;
    padding: 20px;
}
.form-grid {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 16px;
}
</style>
