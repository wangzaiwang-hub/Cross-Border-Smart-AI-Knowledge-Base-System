<script setup lang="ts">
import { onMounted, ref } from "vue";
import { RefreshRight } from "@element-plus/icons-vue";
import { ElMessage, ElMessageBox } from "element-plus";
import {
    dispatchNotifications,
    listDeadLetters,
    listNotificationTemplates,
    replayDeadLetter,
    saveNotificationTemplate,
    type DeadLetter,
    type NotificationTemplate,
} from "@/api/operations";
import EnterpriseTable from "@/components/EnterpriseTable.vue";
const loading = ref(true);
const dispatching = ref(false);
const dead = ref<DeadLetter[]>([]);
const templates = ref<NotificationTemplate[]>([]);
const templateDialog = ref(false);
const editingTemplate = ref<NotificationTemplate>();
async function load() {
    loading.value = true;
    try {
        [dead.value, templates.value] = await Promise.all([
            listDeadLetters(),
            listNotificationTemplates(),
        ]);
    } catch {
        ElMessage.error("死信列表加载失败");
    } finally {
        loading.value = false;
    }
}
function editTemplate(template?: NotificationTemplate) {
    editingTemplate.value = template
        ? { ...template }
        : {
              code: "",
              titleTemplate: "",
              contentTemplate: "",
              channel: "IN_APP",
              enabled: true,
              version: 0,
          };
    templateDialog.value = true;
}
async function persistTemplate() {
    if (!editingTemplate.value) return;
    try {
        await saveNotificationTemplate(editingTemplate.value);
        templates.value = await listNotificationTemplates();
        templateDialog.value = false;
        ElMessage.success("通知模板已保存");
    } catch {
        ElMessage.error("模板保存失败，请检查编码和版本");
    }
}
async function dispatch() {
    dispatching.value = true;
    try {
        const count = await dispatchNotifications();
        ElMessage.success(`已派发 ${count} 条待发送消息`);
    } catch {
        ElMessage.error("通知派发失败");
    } finally {
        dispatching.value = false;
    }
}
async function replay(item: DeadLetter) {
    await ElMessageBox.confirm(
        "确认重放该死信？操作将写入审计日志。",
        "高风险操作",
    );
    try {
        await replayDeadLetter(item.id);
        ElMessage.success("死信重放已受理");
        await load();
    } catch {
        ElMessage.error("死信重放失败");
    }
}
onMounted(load);
</script>
<template>
    <div class="page-head">
        <div>
            <h1>通知与补偿</h1>
            <p>站内信派发、重试与死信人工补偿。</p>
        </div>
        <el-button type="primary" :loading="dispatching" @click="dispatch"
            >立即派发待发送消息</el-button
        >
    </div>
    <div class="metric-grid">
        <div class="metric panel">
            <span>当前死信</span><b>{{ dead.length }}</b
            ><small>需要人工核验</small>
        </div>
    </div>
    <section class="panel table-panel templates">
        <header>
            <b class="serif">通知模板</b
            ><el-button type="primary" @click="editTemplate()"
                >新增模板</el-button
            >
        </header>
        <EnterpriseTable
            :items="templates"
            :search-fields="['code', 'titleTemplate', 'channel']"
            status-field="enabled"
            search-placeholder="检索模板编码、标题或渠道"
            v-slot="{ rows, emptyText }"
        >
        <el-table :data="rows" :empty-text="emptyText"
            ><el-table-column prop="code" label="模板编码" /><el-table-column
                prop="titleTemplate"
                label="标题模板"
            /><el-table-column prop="channel" label="渠道" /><el-table-column
                prop="enabled"
                label="启用"
            /><el-table-column prop="version" label="版本" /><el-table-column
                label="操作"
                ><template #default="scope"
                    ><el-button
                        link
                        type="primary"
                        @click="editTemplate(scope.row)"
                        >编辑</el-button
                    ></template
                ></el-table-column
            ></el-table>
        </EnterpriseTable>
    </section>
    <section v-loading="loading" class="panel table-panel dead">
        <header>
            <b class="serif">死信队列</b
            ><el-tag type="danger">高风险操作需权限</el-tag>
        </header>
        <EnterpriseTable
            :items="dead"
            :search-fields="['id', 'messageId', 'eventId', 'failureReason']"
            search-placeholder="检索死信、消息、事件或失败原因"
            v-slot="{ rows, emptyText }"
        >
        <el-table :data="rows" :empty-text="emptyText"
            ><el-table-column prop="id" label="死信 ID" /><el-table-column
                prop="messageId"
                label="消息 ID"
            /><el-table-column
                prop="eventId"
                label="事件键"
                min-width="220"
            /><el-table-column
                prop="failureReason"
                label="失败原因"
                min-width="260"
            /><el-table-column label="失败时间"
                ><template #default="scope">{{
                    new Date(scope.row.failedAt).toLocaleString("zh-CN")
                }}</template></el-table-column
            ><el-table-column label="操作"
                ><template #default="scope"
                    ><el-button
                        link
                        type="danger"
                        :icon="RefreshRight"
                        @click="replay(scope.row)"
                        >人工重放</el-button
                    ></template
                ></el-table-column
            ></el-table>
        </EnterpriseTable>
    </section>
    <el-dialog v-model="templateDialog" title="维护通知模板" width="620"
        ><el-form v-if="editingTemplate" label-position="top"
            ><el-form-item label="模板编码"
                ><el-input
                    v-model="editingTemplate.code"
                    :disabled="editingTemplate.version > 0" /></el-form-item
            ><el-form-item label="标题模板"
                ><el-input
                    v-model="editingTemplate.titleTemplate" /></el-form-item
            ><el-form-item label="内容模板"
                ><el-input
                    v-model="editingTemplate.contentTemplate"
                    type="textarea"
                    :rows="6"
                /><small
                    >变量使用 <code v-pre>{{ variableName }}</code
                    >，发送时必须提供对应变量。</small
                ></el-form-item
            ><el-form-item label="启用"
                ><el-switch
                    v-model="editingTemplate.enabled" /></el-form-item></el-form
        ><template #footer
            ><el-button @click="templateDialog = false">取消</el-button
            ><el-button type="primary" @click="persistTemplate"
                >保存</el-button
            ></template
        ></el-dialog
    >
</template>
<style scoped>
.dead {
    margin-top: 14px;
}
.templates {
    margin-top: 14px;
}
.templates header,
.dead header {
    display: flex;
    justify-content: space-between;
    margin-bottom: 15px;
}
</style>
