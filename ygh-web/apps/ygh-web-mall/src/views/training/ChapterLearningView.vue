<script setup lang="ts">
import { onBeforeUnmount, onMounted, ref } from "vue";
import { useRoute, useRouter } from "vue-router";
import { ElMessage } from "element-plus";
import {
    ArrowLeft,
    ArrowRight,
    Clock,
    Document,
} from "@element-plus/icons-vue";
import {
    heartbeat,
    listChapterDocuments,
    recordPosition,
    type Progress,
    type TrainingDocument,
} from "@/api/training";
const route = useRoute();
const router = useRouter();
const chapterId = String(route.params.id);
const assignmentId = String(route.query.assignment || "");
const gateId = String(route.query.gate || "");
const seconds = ref(0);
const unsaved = ref(0);
const documents = ref<TrainingDocument[]>([]);
const progress = ref<Progress>();
const saving = ref(false);
let timer = 0;
async function save() {
    if (!assignmentId || unsaved.value <= 0) return;
    saving.value = true;
    const active = Math.min(unsaved.value, 300);
    try {
        progress.value = await heartbeat(assignmentId, chapterId, active);
        await recordPosition(
            assignmentId,
            chapterId,
            `active-seconds:${seconds.value}`,
        );
        unsaved.value -= active;
    } catch {
        ElMessage.error("学习进度保存失败，请保持页面打开后重试");
    } finally {
        saving.value = false;
    }
}
async function finish() {
    await save();
    if (gateId)
        await router.push({
            path: `/workspace/training/quiz/${gateId}`,
            query: { assignment: assignmentId },
        });
    else {
        ElMessage.success("本章没有闯关，进度已由服务端计算");
        router.back();
    }
}
onMounted(async () => {
    if (!assignmentId) {
        ElMessage.error("缺少学习任务参数");
        return;
    }
    try {
        documents.value = await listChapterDocuments(chapterId);
    } catch {
        ElMessage.error("培训文档加载失败");
    }
    timer = window.setInterval(() => {
        if (document.visibilityState === "visible") {
            seconds.value++;
            unsaved.value++;
            if (unsaved.value >= 60) void save();
        }
    }, 1000);
});
onBeforeUnmount(() => {
    clearInterval(timer);
    void save();
});
</script>
<template>
    <div class="learning">
        <header>
            <el-button text :icon="ArrowLeft" @click="$router.back()"
                >返回课程</el-button
            ><b class="serif">章节学习</b>
            <div>
                <el-icon><Clock /></el-icon>{{ Math.floor(seconds / 60) }}:{{
                    String(seconds % 60).padStart(2, "0")
                }}
                本次有效学习
            </div>
        </header>
        <main>
            <section class="paper">
                <span class="label">企业培训文档</span>
                <h1 class="serif">受控课程资料</h1>
                <p class="lead">
                    系统仅在页面可见期间累计学习时间，每 60
                    秒向服务端发送一次带唯一 nonce
                    的心跳。关闭页面前会尝试保存剩余时长。
                </p>
                <el-alert
                    title="完成状态由服务端计算"
                    description="前端不能直接将章节标记为已完成；有效时长达到课程配置后，服务端才允许进入并通过关卡。"
                    type="warning"
                    :closable="false"
                />
                <div class="documents">
                    <article v-for="item in documents" :key="item.id">
                        <el-icon><Document /></el-icon>
                        <div>
                            <b>{{ item.fileName }}</b
                            ><small
                                >{{ item.mediaType }} ·
                                {{
                                    (item.sizeBytes / 1024).toFixed(1)
                                }}
                                KB</small
                            >
                        </div>
                        <el-tag>{{ item.status }}</el-tag>
                    </article>
                    <el-empty
                        v-if="!documents.length"
                        description="本章暂未上传培训文档"
                    />
                </div>
            </section>
        </main>
        <footer>
            <div>
                <span
                    >本次已记录 {{ seconds - unsaved }} 秒，待保存
                    {{ unsaved }} 秒</span
                ><el-progress
                    :percentage="
                        Math.min(100, Number(progress?.progressPercent || 0))
                    "
                    :show-text="false"
                />
            </div>
            <el-button :loading="saving" @click="save">保存进度</el-button
            ><el-button
                type="primary"
                :icon="ArrowRight"
                :disabled="!assignmentId"
                @click="finish"
                >保存并进入闯关</el-button
            >
        </footer>
    </div>
</template>
<style scoped>
.learning {
    height: 100vh;
    display: grid;
    grid-template-rows: 62px 1fr 70px;
    background: #eceee9;
}
.learning > header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 0 24px;
    background: #0a403c;
    color: #fff;
}
.learning > header .el-button {
    color: #d0dfdb;
}
.learning > header > div {
    display: flex;
    align-items: center;
    gap: 7px;
    color: #a9c1bb;
    font-size: 12px;
}
.learning > main {
    overflow: auto;
    padding: 35px;
}
.paper {
    max-width: 850px;
    min-height: 600px;
    margin: 0 auto;
    padding: 48px 60px;
    background: #fff;
    box-shadow: 0 8px 40px rgba(30, 50, 45, 0.08);
}
.label {
    color: var(--cinnabar);
    font-size: 11px;
    letter-spacing: 0.15em;
}
.paper h1 {
    font-size: 36px;
}
.lead {
    color: var(--muted);
    line-height: 1.9;
}
.documents {
    display: grid;
    gap: 10px;
    margin-top: 30px;
}
.documents article {
    display: grid;
    grid-template-columns: 35px 1fr auto;
    align-items: center;
    padding: 16px;
    border: 1px solid var(--line);
}
.documents b,
.documents small {
    display: block;
}
.documents small {
    margin-top: 4px;
    color: var(--muted);
}
.learning > footer {
    display: flex;
    align-items: center;
    justify-content: flex-end;
    gap: 10px;
    padding: 10px 24px;
    background: #fff;
    border-top: 1px solid var(--line);
}
.learning > footer > div {
    width: 300px;
    margin-right: auto;
    font-size: 11px;
}
@media (max-width: 700px) {
    .learning > main {
        padding: 10px;
    }
    .paper {
        padding: 30px 22px;
    }
    .learning > footer > div {
        display: none;
    }
}
</style>
