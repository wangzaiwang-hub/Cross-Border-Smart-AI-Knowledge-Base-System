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
    setEvaluationCaseEnabled,
    type AiSummary,
    type EvaluationCase,
    type EvaluationRun,
    type PromptConfig,
} from "@/api/operations";
import EnterpriseTable from "@/components/EnterpriseTable.vue";
const tab = ref("prompt");
const loading = ref(true);
const running = ref(false);
const prompts = ref<PromptConfig[]>([]);
const cases = ref<EvaluationCase[]>([]);
const summary = ref<AiSummary>();
const runs = ref<EvaluationRun[]>([]);
const promptDialog = ref(false);
const caseDialog = ref(false);
const providerDialog = ref(false);
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
    expectedRefusal: false,
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
async function changeCaseStatus(item: EvaluationCase) {
    try {
        await setEvaluationCaseEnabled(item.id, item.enabled);
        ElMessage.success(item.enabled ? "评测用例已启用" : "评测用例已停用");
        summary.value = await getAiSummary();
    } catch {
        item.enabled = !item.enabled;
        ElMessage.error("评测用例状态更新失败");
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
                <el-button @click="providerDialog = true">模型 API 配置</el-button
                ><el-button @click="caseDialog = true">新增评测用例</el-button
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
                ><EnterpriseTable
                    :items="prompts"
                    :search-fields="['code', 'modelName', 'knowledgeScope']"
                    status-field="enabled"
                    search-placeholder="检索编码、模型或知识范围"
                    v-slot="{ rows, emptyText }"
                ><el-table :data="rows" :empty-text="emptyText"
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
                    ></el-table></EnterpriseTable
                ></el-tab-pane
            ><el-tab-pane label="评测集" name="evaluation"
                ><EnterpriseTable
                    :items="cases"
                    :search-fields="['category', 'question', 'expectedEvidence']"
                    status-field="enabled"
                    search-placeholder="检索分类、问题或预期证据"
                    v-slot="{ rows, emptyText }"
                ><el-table :data="rows" :empty-text="emptyText"
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
                    /><el-table-column label="预期结果"
                        ><template #default="scope"
                            ><el-tag :type="scope.row.expectedRefusal ? 'warning' : 'success'">{{
                                scope.row.expectedRefusal ? "应拒答" : "应回答"
                            }}</el-tag></template
                        ></el-table-column
                    ><el-table-column label="状态" width="100"
                        ><template #default="scope"
                            ><el-switch
                                v-model="scope.row.enabled"
                                @change="changeCaseStatus(scope.row)" /></template
                        ></el-table-column
                    ></el-table></EnterpriseTable
                ><el-button
                    type="primary"
                    :loading="running"
                    style="margin-top: 15px"
                    @click="run"
                    >运行全量评测</el-button
                ></el-tab-pane
            ><el-tab-pane label="最近运行" name="runs"
                ><EnterpriseTable
                    :items="runs"
                    :search-fields="['caseId', 'failureReason']"
                    status-field="passed"
                    search-placeholder="检索用例 ID 或失败原因"
                    v-slot="{ rows, emptyText }"
                ><el-table :data="rows" :empty-text="emptyText"
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
                        label="失败原因" /></el-table></EnterpriseTable></el-tab-pane></el-tabs
        ><el-dialog
            v-model="providerDialog"
            title="豆包模型 API 配置"
            width="720"
        >
            <el-alert
                type="info"
                :closable="false"
                show-icon
                title="API Key 由服务器 Secret 注入"
                description="为避免密钥泄漏，企业后台不保存、不回显 API Key。这里提供唯一配置位置与重启方法；提示词版本中的“模型名称”不是 API Key。"
            />
            <el-descriptions class="provider-details" :column="1" border>
                <el-descriptions-item label="服务商">豆包 Ark</el-descriptions-item>
                <el-descriptions-item label="配置文件">
                    <code>ygh-deploy/constrained-dev/.env</code>
                </el-descriptions-item>
                <el-descriptions-item label="API Key">
                    <code>YGH_DOUBAO_API_KEY</code>
                </el-descriptions-item>
                <el-descriptions-item label="聊天 Endpoint ID">
                    <code>YGH_DOUBAO_CHAT_MODEL</code>
                </el-descriptions-item>
                <el-descriptions-item label="向量 Endpoint ID">
                    <code>YGH_DOUBAO_EMBEDDING_MODEL</code>
                </el-descriptions-item>
                <el-descriptions-item label="默认接口地址">
                    <code>https://ark.cn-beijing.volces.com/api/v3</code>
                </el-descriptions-item>
            </el-descriptions>
            <div class="configuration-steps">
                <b>本机开发环境配置步骤</b>
                <ol>
                    <li>用记事本打开上述 <code>.env</code> 文件。</li>
                    <li>分别填写 API Key、聊天 Endpoint ID 和向量 Endpoint ID。</li>
                    <li>保存文件后，在该目录执行下面的命令重建 AI 服务。</li>
                </ol>
                <pre>docker compose -p ygh-apps --env-file .env -f apps-compose.yml --profile ai-apps up -d --build ai</pre>
                <p>
                    如果 AI 返回 <code>MODEL_NOT_CONFIGURED</code>，说明服务仍未读取到
                    Key 或聊天 Endpoint ID。向量检索还需要按需启动 Elasticsearch 与
                    Search 服务。
                </p>
            </div>
            <template #footer>
                <el-button type="primary" @click="providerDialog = false">我知道了</el-button>
            </template>
        </el-dialog
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
                ><el-form-item label="预期拒答"
                    ><el-switch v-model="caseForm.expectedRefusal" />
                    <span class="form-hint">仅用于已审核知识不足时必须拒答的用例</span></el-form-item
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
.form-hint { margin-left: 10px; color: var(--muted); font-size: 12px; }
.provider-details {
    margin-top: 18px;
}
.provider-details code,
.configuration-steps code {
    color: var(--jade);
    font-family: Consolas, "Courier New", monospace;
}
.configuration-steps {
    margin-top: 18px;
    color: var(--muted);
    line-height: 1.8;
}
.configuration-steps b {
    color: var(--ink);
}
.configuration-steps pre {
    overflow-x: auto;
    padding: 12px;
    border-radius: 6px;
    background: #102d2a;
    color: #f7f3ea;
    font: 12px/1.6 Consolas, "Courier New", monospace;
}
</style>
