<script setup lang="ts">
import { onMounted, reactive, ref } from "vue";
import { ElMessage, ElMessageBox } from "element-plus";
import {
    createScopedTrainingAssignment,
    createTrainingCourse,
    getTrainingAnalytics,
    listTrainingCourses,
    publishTrainingCourse,
    type TrainingAnalytics,
    type TrainingCourse,
} from "@/api/operations";
const tab = ref("courses");
const loading = ref(true);
const data = ref<TrainingAnalytics>();
const courses = ref<TrainingCourse[]>([]);
const courseDialog = ref(false);
const assignmentDialog = ref(false);
const saving = ref(false);
const courseForm = reactive({
    title: "",
    description: "",
    estimatedMinutes: 60,
    passScore: 80,
});
const assignmentForm = reactive<{
    targetType: "DEPARTMENT" | "POSITION" | "EMPLOYEE";
    targetId: string;
    courseId: string;
    dueAt: string;
}>({ targetType: "POSITION", targetId: "", courseId: "", dueAt: "" });
async function load() {
    loading.value = true;
    try {
        [data.value, courses.value] = await Promise.all([
            getTrainingAnalytics(),
            listTrainingCourses(),
        ]);
    } catch {
        ElMessage.error("培训运营数据加载失败");
    } finally {
        loading.value = false;
    }
}
async function createCourse() {
    saving.value = true;
    try {
        await createTrainingCourse(courseForm);
        courseDialog.value = false;
        ElMessage.success("课程草稿已创建");
        await load();
    } catch {
        ElMessage.error("课程创建失败");
    } finally {
        saving.value = false;
    }
}
async function publish(course: TrainingCourse) {
    await ElMessageBox.confirm(
        "发布后课程将对已授权员工可见，确认发布？",
        "发布课程",
    );
    try {
        await publishTrainingCourse(course);
        ElMessage.success("课程已发布");
        await load();
    } catch {
        ElMessage.error("课程发布失败，版本或状态可能已变化");
    }
}
async function assign() {
    saving.value = true;
    try {
        await createScopedTrainingAssignment({
            ...assignmentForm,
            dueAt: assignmentForm.dueAt
                ? new Date(assignmentForm.dueAt).toISOString()
                : undefined,
        });
        assignmentDialog.value = false;
        ElMessage.success("岗位学习任务已分配");
    } catch {
        ElMessage.error("任务分配失败，请核对目标和课程");
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
                <h1>培训运营</h1>
                <p>按部门、岗位和员工维护课程、任务与统计。</p>
            </div>
            <div>
                <el-button @click="assignmentDialog = true">分配任务</el-button
                ><el-button type="primary" @click="courseDialog = true"
                    >新建课程</el-button
                >
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
        <el-tabs v-model="tab" class="panel training"
            ><el-tab-pane label="课程管理" name="courses"
                ><el-table :data="courses"
                    ><el-table-column
                        prop="title"
                        label="课程名称"
                        min-width="240"
                    /><el-table-column
                        prop="estimatedMinutes"
                        label="预计分钟"
                    /><el-table-column
                        prop="passScore"
                        label="通过分数"
                    /><el-table-column
                        prop="version"
                        label="版本"
                    /><el-table-column
                        prop="status"
                        label="状态"
                    /><el-table-column label="操作"
                        ><template #default="scope"
                            ><el-button
                                v-if="scope.row.status === 'DRAFT'"
                                link
                                type="primary"
                                @click="publish(scope.row)"
                                >发布</el-button
                            ></template
                        ></el-table-column
                    ></el-table
                ></el-tab-pane
            ><el-tab-pane label="学习分析" name="analytics"
                ><el-table :data="data?.weakKnowledge || []"
                    ><el-table-column
                        prop="knowledgeCode"
                        label="知识点编码" /><el-table-column
                        prop="wrongCount"
                        label="错误次数" /></el-table></el-tab-pane></el-tabs
        ><el-dialog v-model="courseDialog" title="新建培训课程" width="540"
            ><el-form label-position="top"
                ><el-form-item label="课程名称"
                    ><el-input
                        v-model="courseForm.title"
                        maxlength="200" /></el-form-item
                ><el-form-item label="课程说明"
                    ><el-input
                        v-model="courseForm.description"
                        type="textarea"
                        maxlength="5000" /></el-form-item
                ><el-form-item label="预计分钟"
                    ><el-input-number
                        v-model="courseForm.estimatedMinutes"
                        :min="0" /></el-form-item
                ><el-form-item label="通过分数"
                    ><el-input-number
                        v-model="courseForm.passScore"
                        :min="0"
                        :max="100" /></el-form-item></el-form
            ><template #footer
                ><el-button @click="courseDialog = false">取消</el-button
                ><el-button
                    type="primary"
                    :loading="saving"
                    @click="createCourse"
                    >创建草稿</el-button
                ></template
            ></el-dialog
        ><el-dialog
            v-model="assignmentDialog"
            title="按组织范围分配课程"
            width="540"
            ><el-form label-position="top"
                ><el-form-item label="目标类型"
                    ><el-radio-group v-model="assignmentForm.targetType"
                        ><el-radio-button value="DEPARTMENT"
                            >部门</el-radio-button
                        ><el-radio-button value="POSITION">岗位</el-radio-button
                        ><el-radio-button value="EMPLOYEE"
                            >员工</el-radio-button
                        ></el-radio-group
                    ></el-form-item
                ><el-form-item label="目标 ID"
                    ><el-input
                        v-model="assignmentForm.targetId" /></el-form-item
                ><el-form-item label="课程"
                    ><el-select
                        v-model="assignmentForm.courseId"
                        style="width: 100%"
                        ><el-option
                            v-for="course in courses.filter(
                                (x) => x.status === 'PUBLISHED',
                            )"
                            :key="course.id"
                            :label="course.title"
                            :value="course.id" /></el-select></el-form-item
                ><el-form-item label="截止时间"
                    ><el-date-picker
                        v-model="assignmentForm.dueAt"
                        type="datetime"
                        value-format="YYYY-MM-DDTHH:mm:ss"
                        style="width: 100%" /></el-form-item></el-form
            ><template #footer
                ><el-button @click="assignmentDialog = false">取消</el-button
                ><el-button type="primary" :loading="saving" @click="assign"
                    >确认分配</el-button
                ></template
            ></el-dialog
        >
    </div>
</template>
<style scoped>
.training {
    margin-top: 14px;
    padding: 18px;
}
</style>
