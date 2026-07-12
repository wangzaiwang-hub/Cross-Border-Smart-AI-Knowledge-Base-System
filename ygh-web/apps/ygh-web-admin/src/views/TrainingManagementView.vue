<script setup lang="ts">
import { onMounted, ref } from "vue";
import { ElMessage } from "element-plus";
import { getTrainingAnalytics, type TrainingAnalytics } from "@/api/operations";
const loading = ref(true);
const data = ref<TrainingAnalytics>();
onMounted(async () => {
    try {
        data.value = await getTrainingAnalytics();
    } catch {
        ElMessage.error("培训分析加载失败");
    } finally {
        loading.value = false;
    }
});
</script>
<template>
    <div v-loading="loading">
        <div class="page-head">
            <div>
                <h1>培训运营</h1>
                <p>服务端汇总任务完成、逾期、成绩与薄弱知识点。</p>
            </div>
        </div>
        <div class="metric-grid">
            <div class="metric panel">
                <span>已分配</span><b>{{ data?.assigned || 0 }}</b>
            </div>
            <div class="metric panel">
                <span>已完成</span><b>{{ data?.completed || 0 }}</b>
            </div>
            <div class="metric panel">
                <span>逾期任务</span><b>{{ data?.overdue || 0 }}</b>
            </div>
            <div class="metric panel">
                <span>平均成绩</span><b>{{ data?.averageScore || 0 }}</b>
            </div>
        </div>
        <section class="panel table-panel">
            <h3 class="serif">薄弱知识点</h3>
            <el-table :data="data?.weakKnowledge || []"
                ><el-table-column
                    prop="knowledgeCode"
                    label="知识点编码" /><el-table-column
                    prop="wrongCount"
                    label="错误次数" /></el-table
            ><el-empty
                v-if="!data?.weakKnowledge.length"
                description="暂无薄弱知识点数据"
            />
        </section>
    </div>
</template>
