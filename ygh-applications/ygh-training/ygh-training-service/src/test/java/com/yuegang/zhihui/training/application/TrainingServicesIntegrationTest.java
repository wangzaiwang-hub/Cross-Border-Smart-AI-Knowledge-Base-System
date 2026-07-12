package com.yuegang.zhihui.training.application;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.yuegang.zhihui.common.core.BusinessException;
import com.yuegang.zhihui.common.test.YghTestContainerFactory;
import com.yuegang.zhihui.training.api.*;
import java.nio.file.Files;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.Map;
import org.flywaydb.core.Flyway;
import org.junit.jupiter.api.Test;
import org.springframework.jdbc.datasource.DriverManagerDataSource;
import org.springframework.mock.web.MockMultipartFile;

class TrainingServicesIntegrationTest {
    @Test
    void completesPublishedCourseLearningAndQuizJourney() throws Exception {
        try (var mysql = YghTestContainerFactory.mysql().start()) {
            Flyway.configure().dataSource(mysql.jdbcUrl(), mysql.username(), mysql.credential())
                    .locations("classpath:db/migration").load().migrate();
            var dataSource = new DriverManagerDataSource(
                    mysql.jdbcUrl(), mysql.username(), mysql.credential());
            var json = new ObjectMapper();
            var content = new TrainingContentService(
                    dataSource, json, Files.createTempDirectory("training-content").toString());

            CourseView course = content.createCourse(
                    new SaveCourseRequest("跨境通关基础", "岗位必修", 30, 80));
            ChapterView chapter = content.createChapter(
                    new SaveChapterRequest(course.id(), "申报准备", 1, 30));
            GateView gate = content.createGate(
                    new SaveGateRequest(chapter.id(), "通关测验", 80, 2));
            QuestionView question = content.createQuestion(new SaveQuestionRequest(
                    gate.id(), "SINGLE", "申报前应核对什么？", List.of("资料", "忽略"),
                    "资料", "核对申报资料", 100));
            content.createQuestion(new SaveQuestionRequest(
                    gate.id(), "TEXT", "补充说明", null, "完成", null, 1));
            assertThat(content.questions(gate.id())).hasSize(2)
                    .extracting(QuestionView::stem)
                    .containsExactlyInAnyOrder("申报前应核对什么？", "补充说明");
            assertThat(content.chapters(course.id())).hasSize(1);
            assertThat(content.courses(true)).isEmpty();
            assertThat(content.courses(false)).hasSize(1);
            assertThat(content.upload(chapter.id(), new MockMultipartFile(
                    "file", "lesson.txt", "text/plain", "training material".getBytes())).mediaType())
                    .isEqualTo("text/plain");
            assertThatThrownBy(() -> content.upload(chapter.id(), null))
                    .isInstanceOf(BusinessException.class);
            assertThatThrownBy(() -> content.upload(chapter.id(), new MockMultipartFile(
                    "file", "empty.txt", "text/plain", new byte[0])))
                    .isInstanceOf(BusinessException.class);

            var paths = new LearningPathService(dataSource);
            LearningPathView path = paths.create(new SaveLearningPathRequest("CUSTOMS", "关务学习路径"));
            assertThat(paths.addCourse(path.id(), new AddPathCourseRequest(course.id(), 1, null)).courses())
                    .hasSize(1);
            assertThat(paths.byPosition("CUSTOMS")).hasSize(1);
            assertThat(paths.all()).hasSize(1);

            CourseView published = content.publish(course.id(), course.version());
            assertThat(published.status()).isEqualTo("PUBLISHED");
            assertThat(content.courses(true)).hasSize(1);
            assertThatThrownBy(() -> content.publish(course.id(), course.version()))
                    .isInstanceOf(BusinessException.class);

            var assignments = new TrainingAssignmentService(dataSource, json);
            var records = new TrainingLearningRecordService(dataSource, json);
            assertThat(records.analytics().assigned()).isZero();
            AssignmentView assignment = assignments.assign(9, new CreateAssignmentRequest(
                    "42", path.id(), course.id(), OffsetDateTime.now().plusDays(7)));
            assertThat(assignments.mine(42)).singleElement()
                    .extracting(AssignmentView::assignmentId).isEqualTo(assignment.assignmentId());
            assertThat(assignments.statistics().assigned()).isEqualTo(1);

            var progress = new TrainingProgressService(dataSource);
            assertThat(progress.get(42, assignment.assignmentId()).progressPercent()).isZero();
            ProgressView learned = progress.heartbeat(42, new LearningHeartbeat(
                    assignment.assignmentId(), chapter.id(), 30, "heartbeat-1"));
            assertThat(learned.progressPercent()).isEqualByComparingTo("100.00");
            assertThat(progress.heartbeat(42, new LearningHeartbeat(
                    assignment.assignmentId(), chapter.id(), 30, "heartbeat-1")).progressPercent())
                    .isEqualByComparingTo("100.00");

            records.recordPosition(42, new ReadingPositionRequest(
                    assignment.assignmentId(), chapter.id(), "page=2", "position-1"));
            records.recordPosition(42, new ReadingPositionRequest(
                    assignment.assignmentId(), chapter.id(), "page=9", "position-1"));
            assertThat(records.progress(42, assignment.assignmentId())).singleElement()
                    .extracting(ChapterProgressView::lastPosition).isEqualTo("page=2");

            var quizzes = new TrainingQuizService(dataSource, json);
            SubmitQuizRequest wrongSubmission = new SubmitQuizRequest(
                    assignment.assignmentId(), gate.id(), Map.of(question.id(), "忽略"), "quiz-request-wrong");
            assertThat(quizzes.submit(42, wrongSubmission).passed()).isFalse();
            SubmitQuizRequest submission = new SubmitQuizRequest(
                    assignment.assignmentId(), gate.id(), Map.of(question.id(), "资料"), "quiz-request-1");
            QuizAttemptView attempt = quizzes.submit(42, submission);
            assertThat(attempt.passed()).isTrue();
            assertThat(quizzes.submit(42, submission).attemptId()).isEqualTo(attempt.attemptId());
            assertThat(records.attempts(42, assignment.assignmentId())).hasSize(2);
            assertThatThrownBy(() -> quizzes.submit(42, new SubmitQuizRequest(
                    assignment.assignmentId(), gate.id(), Map.of(), "quiz-request-over-limit")))
                    .isInstanceOf(BusinessException.class);
            assertThat(records.analytics().completed()).isEqualTo(1);
            assertThat(assignments.statistics().completed()).isEqualTo(1);

            assertThatThrownBy(() -> progress.get(7, assignment.assignmentId()))
                    .isInstanceOf(BusinessException.class);
            assertThatThrownBy(() -> paths.addCourse("bad", new AddPathCourseRequest(course.id(), 1, null)))
                    .isInstanceOf(BusinessException.class);
            assertThatThrownBy(() -> records.progress(7, assignment.assignmentId()))
                    .isInstanceOf(BusinessException.class);
        }
    }
}
