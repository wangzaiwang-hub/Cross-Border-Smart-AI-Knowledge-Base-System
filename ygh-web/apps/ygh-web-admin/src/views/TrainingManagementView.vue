<script setup lang="ts">
import { onMounted, reactive, ref } from "vue";
import { ElMessage, ElMessageBox } from "element-plus";
import {
    createScopedTrainingAssignment,
    createTrainingChapter,
    createTrainingCourse,
    createTrainingGate,
    createTrainingQuestion,
    getTrainingAnalytics,
    listTrainingCourses,
    listTrainingChapters,
    listTrainingGates,
    publishTrainingCourse,
    uploadTrainingDocument,
    type TrainingChapter,
    type TrainingAnalytics,
    type TrainingCourse,
    type TrainingGate,
} from "@/api/operations";
const tab = ref("courses");
const loading = ref(true);
const data = ref<TrainingAnalytics>();
const courses = ref<TrainingCourse[]>([]);
const courseDialog = ref(false);
const assignmentDialog = ref(false);
const contentDialog = ref(false);
const saving = ref(false);
const selectedCourse = ref<TrainingCourse>();
const chapters = ref<TrainingChapter[]>([]);
const gates = ref<TrainingGate[]>([]);
const selectedChapterId = ref("");
const selectedGateId = ref("");
const documentFile = ref<File>();
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
const chapterForm = reactive({
    title: "",
    sequenceNo: 1,
    minimumActiveSeconds: 60,
});
const gateForm = reactive({ title: "", passScore: 80, maximumAttempts: 3 });
const questionForm = reactive({
    type: "SINGLE_CHOICE",
    stem: "",
    optionsText: "",
    correctAnswer: "",
    explanation: "",
    score: 10,
});
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
async function openContent(course: TrainingCourse) {
    selectedCourse.value = course;
    chapters.value = await listTrainingChapters(course.id);
    selectedChapterId.value = chapters.value[0]?.id ?? "";
    await loadGates();
    contentDialog.value = true;
}
async function loadGates() {
    gates.value = selectedChapterId.value
        ? await listTrainingGates(selectedChapterId.value)
        : [];
    selectedGateId.value = gates.value[0]?.id ?? "";
}
async function addChapter() {
    if (!selectedCourse.value || !chapterForm.title.trim()) return;
    saving.value = true;
    try {
        await createTrainingChapter({
            courseId: selectedCourse.value.id,
            ...chapterForm,
        });
        chapters.value = await listTrainingChapters(selectedCourse.value.id);
        chapterForm.title = "";
        ElMessage.success("章节已创建");
    } catch {
        ElMessage.error("章节创建失败");
    } finally {
        saving.value = false;
    }
}
async function addGate() {
    if (!selectedChapterId.value || !gateForm.title.trim()) return;
    saving.value = true;
    try {
        await createTrainingGate({
            chapterId: selectedChapterId.value,
            ...gateForm,
        });
        await loadGates();
        gateForm.title = "";
        ElMessage.success("关卡已创建");
    } catch {
        ElMessage.error("关卡创建失败");
    } finally {
        saving.value = false;
    }
}
async function addQuestion() {
    if (!selectedGateId.value || !questionForm.stem.trim()) return;
    saving.value = true;
    try {
        await createTrainingQuestion({
            gateId: selectedGateId.value,
            ...questionForm,
            options: questionForm.optionsText
                .split("\n")
                .map((item) => item.trim())
                .filter(Boolean),
        });
        questionForm.stem = "";
        questionForm.optionsText = "";
        questionForm.correctAnswer = "";
        questionForm.explanation = "";
        ElMessage.success("题目已创建");
    } catch {
        ElMessage.error("题目创建失败");
    } finally {
        saving.value = false;
    }
}
async function uploadDocument() {
    if (!selectedChapterId.value || !documentFile.value) return;
    saving.value = true;
    try {
        await uploadTrainingDocument(
            selectedChapterId.value,
            documentFile.value,
        );
        documentFile.value = undefined;
        ElMessage.success("培训文档已上传并等待处理");
    } catch {
        ElMessage.error("文档上传失败");
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
                            ><el-button link @click="openContent(scope.row)"
                                >内容编排</el-button
                            >
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
        ><el-dialog
            v-model="contentDialog"
            :title="`${selectedCourse?.title || ''} · 内容编排`"
            width="880"
        >
            <el-tabs>
                <el-tab-pane label="章节">
                    <el-form label-position="top" class="editor-grid">
                        <el-form-item label="章节标题">
                            <el-input v-model="chapterForm.title" />
                        </el-form-item>
                        <el-form-item label="顺序">
                            <el-input-number
                                v-model="chapterForm.sequenceNo"
                                :min="1"
                            />
                        </el-form-item>
                        <el-form-item label="最少有效学习秒数">
                            <el-input-number
                                v-model="chapterForm.minimumActiveSeconds"
                                :min="0"
                            />
                        </el-form-item>
                    </el-form>
                    <el-button
                        type="primary"
                        :loading="saving"
                        @click="addChapter"
                        >新增章节</el-button
                    >
                </el-tab-pane>
                <el-tab-pane label="文档与关卡">
                    <el-form label-position="top">
                        <el-form-item label="章节">
                            <el-select
                                v-model="selectedChapterId"
                                style="width: 100%"
                                @change="loadGates"
                            >
                                <el-option
                                    v-for="chapter in chapters"
                                    :key="chapter.id"
                                    :label="`${chapter.sequenceNo}. ${chapter.title}`"
                                    :value="chapter.id"
                                />
                            </el-select>
                        </el-form-item>
                        <el-form-item label="培训文档">
                            <input
                                type="file"
                                accept=".pdf,.docx,.txt,.md"
                                @change="
                                    documentFile = (
                                        $event.target as HTMLInputElement
                                    ).files?.[0]
                                "
                            />
                            <el-button
                                :disabled="!documentFile"
                                :loading="saving"
                                @click="uploadDocument"
                                >上传</el-button
                            >
                        </el-form-item>
                    </el-form>
                    <el-divider>新增关卡</el-divider>
                    <el-form label-position="top" class="editor-grid">
                        <el-form-item label="关卡标题">
                            <el-input v-model="gateForm.title" />
                        </el-form-item>
                        <el-form-item label="通过分数">
                            <el-input-number
                                v-model="gateForm.passScore"
                                :min="0"
                                :max="100"
                            />
                        </el-form-item>
                        <el-form-item label="最多尝试次数">
                            <el-input-number
                                v-model="gateForm.maximumAttempts"
                                :min="1"
                            />
                        </el-form-item>
                    </el-form>
                    <el-button type="primary" :loading="saving" @click="addGate"
                        >新增关卡</el-button
                    >
                </el-tab-pane>
                <el-tab-pane label="题库">
                    <el-form label-position="top">
                        <el-form-item label="关卡">
                            <el-select
                                v-model="selectedGateId"
                                style="width: 100%"
                            >
                                <el-option
                                    v-for="gate in gates"
                                    :key="gate.id"
                                    :label="gate.title"
                                    :value="gate.id"
                                />
                            </el-select>
                        </el-form-item>
                        <el-form-item label="题干">
                            <el-input
                                v-model="questionForm.stem"
                                type="textarea"
                            />
                        </el-form-item>
                        <el-form-item label="选项（每行一个）">
                            <el-input
                                v-model="questionForm.optionsText"
                                type="textarea"
                                :rows="4"
                            />
                        </el-form-item>
                        <el-form-item label="正确答案">
                            <el-input v-model="questionForm.correctAnswer" />
                        </el-form-item>
                        <el-form-item label="解析">
                            <el-input
                                v-model="questionForm.explanation"
                                type="textarea"
                            />
                        </el-form-item>
                        <el-form-item label="分值">
                            <el-input-number
                                v-model="questionForm.score"
                                :min="1"
                            />
                        </el-form-item>
                    </el-form>
                    <el-button
                        type="primary"
                        :loading="saving"
                        @click="addQuestion"
                        >新增题目</el-button
                    >
                </el-tab-pane>
            </el-tabs>
        </el-dialog>
    </div>
</template>
<style scoped>
.training {
    margin-top: 14px;
    padding: 18px;
}
.editor-grid {
    display: grid;
    grid-template-columns: 2fr 1fr 1fr;
    gap: 0 16px;
}
</style>
