package com.yuegang.zhihui.ai.application;

import static org.assertj.core.api.Assertions.assertThat;

import com.yuegang.zhihui.common.test.YghTestContainerFactory;
import java.sql.DriverManager;
import java.util.HashSet;
import org.flywaydb.core.Flyway;
import org.junit.jupiter.api.Test;

class EnterpriseEvaluationDatasetTest {

    @Test
    void seedsEveryRequiredEnterpriseQuestionCategory() throws Exception {
        try (var mysql = YghTestContainerFactory.mysql().start()) {
            Flyway.configure()
                    .dataSource(mysql.jdbcUrl(), mysql.username(), mysql.credential())
                    .locations("classpath:db/migration")
                    .load()
                    .migrate();

            var categories = new HashSet<String>();
            try (var connection = DriverManager.getConnection(
                            mysql.jdbcUrl(), mysql.username(), mysql.credential());
                    var statement = connection.prepareStatement(
                            "SELECT category FROM ai_evaluation_case");
                    var rows = statement.executeQuery()) {
                while (rows.next()) {
                    categories.add(rows.getString(1));
                }
            }

            assertThat(categories)
                    .contains("POLICY", "CUSTOMS", "TRACEABILITY", "RECOMMENDATION");
        }
    }
}
