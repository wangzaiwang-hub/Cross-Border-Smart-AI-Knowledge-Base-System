<script setup lang="ts">
import { onMounted, ref } from "vue";
import { RefreshRight } from "@element-plus/icons-vue";
import { ElMessage, ElMessageBox } from "element-plus";
import {
    dispatchNotifications,
    listDeadLetters,
    replayDeadLetter,
    type DeadLetter,
} from "@/api/operations";
const loading = ref(true);
const dispatching = ref(false);
const dead = ref<DeadLetter[]>([]);
async function load() {
    loading.value = true;
    try {
        dead.value = await listDeadLetters();
    } catch {
        ElMessage.error("死信列表加载失败");
    } finally {
        loading.value = false;
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
    <section v-loading="loading" class="panel table-panel dead">
        <header>
            <b class="serif">死信队列</b
            ><el-tag type="danger">高风险操作需权限</el-tag>
        </header>
        <el-table :data="dead" empty-text="暂无死信"
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
            ></el-table
        >
    </section>
</template>
<style scoped>
.dead {
    margin-top: 14px;
}
.dead header {
    display: flex;
    justify-content: space-between;
    margin-bottom: 15px;
}
</style>
