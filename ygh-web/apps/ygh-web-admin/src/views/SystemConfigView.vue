<script setup lang="ts">
import { onMounted, ref } from "vue";
import { ElMessage } from "element-plus";
import {
    listDictionaries,
    listFeatureFlags,
    listSystemSettings,
    saveFeatureFlag,
    type Dictionary,
    type FeatureFlag,
    type SystemSetting,
} from "@/api/operations";
const tab = ref("dictionary");
const loading = ref(true);
const dictionaries = ref<Dictionary[]>([]);
const flags = ref<FeatureFlag[]>([]);
const settings = ref<SystemSetting[]>([]);
async function toggleFlag(flag: FeatureFlag) {
    try {
        const saved = await saveFeatureFlag(flag);
        Object.assign(flag, saved);
        ElMessage.success("功能开关已更新");
    } catch {
        flag.enabled = !flag.enabled;
        ElMessage.error("功能开关更新失败，版本可能已变化");
    }
}
onMounted(async () => {
    try {
        [dictionaries.value, flags.value, settings.value] = await Promise.all([
            listDictionaries(),
            listFeatureFlags(),
            listSystemSettings(),
        ]);
    } catch {
        ElMessage.error("系统配置加载失败");
    } finally {
        loading.value = false;
    }
});
</script>
<template>
    <div class="page-head">
        <div>
            <h1>系统配置</h1>
            <p>维护数据字典、业务参数和功能开关。Secret 不在此页面显示。</p>
        </div>
    </div>
    <el-tabs v-model="tab" v-loading="loading" class="panel config"
        ><el-tab-pane label="数据字典" name="dictionary"
            ><el-table :data="dictionaries"
                ><el-table-column
                    prop="code"
                    label="字典编码"
                /><el-table-column
                    prop="name"
                    label="字典名称"
                /><el-table-column label="字典项"
                    ><template #default="scope">{{
                        scope.row.items.length
                    }}</template></el-table-column
                ></el-table
            ></el-tab-pane
        ><el-tab-pane label="业务参数" name="parameters"
            ><el-table :data="settings"
                ><el-table-column prop="key" label="参数键" /><el-table-column
                    label="参数值"
                    ><template #default="scope">{{
                        scope.row.secret ? "[REDACTED]" : scope.row.value
                    }}</template></el-table-column
                ><el-table-column
                    prop="valueType"
                    label="类型" /><el-table-column
                    prop="version"
                    label="版本" /></el-table></el-tab-pane
        ><el-tab-pane label="功能开关" name="switches"
            ><div v-for="flag in flags" :key="flag.key" class="switch">
                <div>
                    <b>{{ flag.key }}</b
                    ><small
                        >灰度 {{ flag.rolloutPercent }}% · 版本
                        {{ flag.version }}</small
                    >
                </div>
                <div class="flag-control">
                    <el-input-number
                        v-model="flag.rolloutPercent"
                        :min="0"
                        :max="100"
                        size="small"
                        @change="toggleFlag(flag)"
                    /><el-switch
                        v-model="flag.enabled"
                        @change="toggleFlag(flag)"
                    />
                </div></div></el-tab-pane
    ></el-tabs>
</template>
<style scoped>
.config {
    padding: 20px;
}
.switch {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 15px;
    border-bottom: 1px solid var(--line);
}
.switch b,
.switch small {
    display: block;
}
.flag-control {
    display: flex;
    align-items: center;
    gap: 12px;
}
.switch small {
    margin-top: 4px;
    color: var(--muted);
}
</style>
