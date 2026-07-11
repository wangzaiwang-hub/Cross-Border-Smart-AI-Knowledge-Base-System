package com.yuegang.zhihui.auth;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.yuegang.zhihui.common.test.YghTestContainerFactory;
import com.yuegang.zhihui.common.test.JdbcContainerFixture;
import java.sql.DriverManager;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.util.LinkedHashSet;
import org.flywaydb.core.Flyway;
import org.junit.jupiter.api.Test;
import org.springframework.boot.WebApplicationType;
import org.springframework.boot.builder.SpringApplicationBuilder;
import org.springframework.boot.web.server.servlet.context.ServletWebServerApplicationContext;

class AuthSchemaMigrationTest {

    @Test
    void emptyMysql84DatabaseMigratesAndValidatesIdempotently() throws Exception {
        try (var fixture = YghTestContainerFactory.mysql().start()) {
            String migrationUser = "auth_migration_test";
            String migrationPassword = "MigrationPassword123456789";
            String appUser = "auth_app_test";
            String appPassword = "ApplicationPassword123456789";
            provisionSeparatedUsers(fixture, migrationUser, migrationPassword, appUser, appPassword);
            Flyway flyway = Flyway.configure()
                    .dataSource(fixture.jdbcUrl(), migrationUser, migrationPassword)
                    .locations("classpath:db/migration")
                    .cleanDisabled(true)
                    .baselineOnMigrate(false)
                    .outOfOrder(false)
                    .validateOnMigrate(true)
                    .load();

            var first = flyway.migrate();
            flyway.validate();
            var second = flyway.migrate();
            grantAppTablePrivileges(fixture, appUser);

            assertThat(first.migrationsExecuted).isEqualTo(1);
            assertThat(second.migrationsExecuted).isZero();
            try (var connection = DriverManager.getConnection(
                    fixture.jdbcUrl(), fixture.username(), fixture.credential())) {
                assertThat(tableNames(connection)).contains(
                        "auth_account",
                        "auth_credential",
                        "auth_refresh_token",
                        "auth_login_attempt",
                        "flyway_schema_history");
                assertThat(columnNames(connection, "auth_account")).contains(
                        "id", "user_id", "principal", "account_type", "status",
                        "failed_login_count", "locked_until", "last_login_at", "version",
                        "created_at", "updated_at");
                assertThat(columnNames(connection, "auth_credential")).contains(
                        "account_id", "password_hash", "password_algorithm",
                        "password_version", "changed_at");
                assertThat(columnNames(connection, "auth_refresh_token")).contains(
                        "account_id", "token_hash", "token_family", "expires_at",
                        "revoked_at", "replaced_by_token_id");
                assertThat(columnNames(connection, "auth_login_attempt")).contains(
                        "principal_hash", "client_ip", "result", "failure_reason",
                        "occurred_at", "trace_id");
                assertThat(indexNames(connection, "auth_account"))
                        .contains("uk_auth_account_principal", "idx_auth_account_status");
                assertThat(indexNames(connection, "auth_refresh_token"))
                        .contains("uk_auth_refresh_token_hash", "idx_auth_refresh_account_family_expiry",
                                "idx_auth_refresh_expiry");
                assertThat(indexNames(connection, "auth_login_attempt"))
                        .contains("idx_auth_login_occurred_at");
                assertThat(importedKeyTables(connection, "auth_credential"))
                        .contains("auth_account");
            }

            try (var context = new SpringApplicationBuilder(AuthApplication.class)
                    .web(WebApplicationType.NONE)
                    .properties(
                            "YGH_AUTH_DB_URL=" + fixture.jdbcUrl(),
                            "YGH_AUTH_DB_APP_USERNAME=" + appUser,
                            "YGH_AUTH_DB_APP_PASSWORD=" + appPassword,
                            "YGH_AUTH_DB_MIGRATION_USERNAME=" + migrationUser,
                            "YGH_AUTH_DB_MIGRATION_PASSWORD=" + migrationPassword,
                            "spring.cloud.nacos.discovery.enabled=false",
                            "YGH_NACOS_SERVER_ADDR=127.0.0.1:8848",
                            "YGH_NACOS_USERNAME=test",
                            "YGH_NACOS_PASSWORD=test")
                    .run()) {
                assertThat(context.isActive()).isTrue();
            }

            try (var runtimeContext = new SpringApplicationBuilder(AuthApplication.class)
                    .web(WebApplicationType.SERVLET)
                    .properties(
                            "YGH_AUTH_DB_URL=" + fixture.jdbcUrl(),
                            "YGH_AUTH_DB_APP_USERNAME=" + appUser,
                            "YGH_AUTH_DB_APP_PASSWORD=" + appPassword,
                            "spring.flyway.enabled=false",
                            "YGH_AUTH_PORT=0",
                            "spring.cloud.nacos.discovery.enabled=false",
                            "YGH_NACOS_SERVER_ADDR=127.0.0.1:8848",
                            "YGH_NACOS_USERNAME=test",
                            "YGH_NACOS_PASSWORD=test")
                    .run()) {
                assertThat(runtimeContext.isActive()).isTrue();
                assertThat(runtimeContext.containsBean("flyway")).isFalse();
                assertThat(runtimeContext.getBean(
                        com.yuegang.zhihui.common.web.GlobalExceptionHandler.class)).isNotNull();
                int port = ((ServletWebServerApplicationContext) runtimeContext)
                        .getWebServer().getPort();
                assertRuntimeErrorEnvelope(port);
            }

            try (var appConnection = DriverManager.getConnection(
                    fixture.jdbcUrl(), appUser, appPassword)) {
                appConnection.createStatement().executeUpdate("""
                        INSERT INTO auth_account
                        (id, user_id, principal, account_type, status)
                        VALUES (1, 1, 'user@example.test', 'PASSWORD', 'ACTIVE')
                        """);
                assertThat(queryCount(appConnection, "auth_account")).isEqualTo(1);
                assertThatThrownBy(() -> appConnection.createStatement()
                        .execute("CREATE TABLE forbidden_ddl (id BIGINT)"))
                        .isInstanceOf(java.sql.SQLException.class);
                assertThatThrownBy(() -> appConnection.createStatement()
                        .executeUpdate("DELETE FROM flyway_schema_history WHERE 1 = 0"))
                        .isInstanceOf(java.sql.SQLException.class);
            }
        }
    }

    private static void assertRuntimeErrorEnvelope(int port) throws Exception {
        var client = HttpClient.newHttpClient();
        var malformed = HttpRequest.newBuilder(URI.create(
                        "http://127.0.0.1:" + port + "/api/v1/auth/login"))
                .header("Content-Type", "application/json")
                .header("X-Trace-Id", "trace-malformed")
                .POST(HttpRequest.BodyPublishers.ofString(
                        "{\"principal\":\"user\",\"password\":\"Sensitive-123\""))
                .build();
        var malformedResponse = client.send(malformed, HttpResponse.BodyHandlers.ofString());
        assertThat(malformedResponse.statusCode()).isEqualTo(400);
        String malformedTrace = malformedResponse.headers()
                .firstValue("X-Trace-Id").orElseThrow();
        assertThat(malformedResponse.body()).contains("VALIDATION_ERROR", malformedTrace)
                .doesNotContain("Sensitive-123");

        var unavailable = HttpRequest.newBuilder(URI.create(
                        "http://127.0.0.1:" + port + "/api/v1/auth/login"))
                .header("Content-Type", "application/json")
                .header("X-Trace-Id", "trace-unavailable")
                .POST(HttpRequest.BodyPublishers.ofString(
                        "{\"principal\":\"user\",\"password\":\"Sensitive-456\"}"))
                .build();
        var unavailableResponse = client.send(unavailable, HttpResponse.BodyHandlers.ofString());
        assertThat(unavailableResponse.statusCode()).isEqualTo(503);
        String unavailableTrace = unavailableResponse.headers()
                .firstValue("X-Trace-Id").orElseThrow();
        assertThat(unavailableResponse.body()).contains("DEPENDENCY_UNAVAILABLE", unavailableTrace)
                .doesNotContain("Sensitive-456");

        var wrongMethod = HttpRequest.newBuilder(URI.create(
                        "http://127.0.0.1:" + port + "/api/v1/auth/login"))
                .PUT(HttpRequest.BodyPublishers.noBody()).build();
        var wrongMethodResponse = client.send(wrongMethod, HttpResponse.BodyHandlers.ofString());
        assertThat(wrongMethodResponse.statusCode()).isEqualTo(405);
        assertThat(wrongMethodResponse.headers().firstValue("Allow")).hasValue("POST");
        assertThat(wrongMethodResponse.body()).contains("VALIDATION_ERROR");

        var wrongMediaType = HttpRequest.newBuilder(URI.create(
                        "http://127.0.0.1:" + port + "/api/v1/auth/login"))
                .header("Content-Type", "text/plain")
                .POST(HttpRequest.BodyPublishers.ofString("Sensitive-789"))
                .build();
        var wrongMediaResponse = client.send(wrongMediaType, HttpResponse.BodyHandlers.ofString());
        assertThat(wrongMediaResponse.statusCode()).isEqualTo(415);
        assertThat(wrongMediaResponse.headers().firstValue("Accept").orElse(""))
                .contains("application/json");
        assertThat(wrongMediaResponse.body()).contains("VALIDATION_ERROR")
                .doesNotContain("Sensitive-789");

        var missing = HttpRequest.newBuilder(URI.create(
                        "http://127.0.0.1:" + port + "/api/v1/auth/not-a-real-resource"))
                .GET().build();
        var missingResponse = client.send(missing, HttpResponse.BodyHandlers.ofString());
        assertThat(missingResponse.statusCode()).isEqualTo(404);
        assertThat(missingResponse.body()).contains("RESOURCE_NOT_FOUND")
                .doesNotContain("not-a-real-resource");
    }

    private static void provisionSeparatedUsers(
            JdbcContainerFixture fixture,
            String migrationUser,
            String migrationPassword,
            String appUser,
            String appPassword
    ) throws Exception {
        try (var connection = DriverManager.getConnection(
                fixture.jdbcUrl(), fixture.adminUsername(), fixture.adminCredential());
                var statement = connection.createStatement()) {
            statement.execute("CREATE USER '" + migrationUser + "'@'%' IDENTIFIED BY '"
                    + migrationPassword + "'");
            statement.execute("CREATE USER '" + appUser + "'@'%' IDENTIFIED BY '"
                    + appPassword + "'");
            String catalog = connection.getCatalog().replace("`", "``");
            statement.execute("GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, ALTER, INDEX, "
                    + "REFERENCES, DROP ON `" + catalog + "`.* TO '" + migrationUser + "'@'%'");
        }
    }

    private static void grantAppTablePrivileges(
            JdbcContainerFixture fixture, String appUser) throws Exception {
        try (var connection = DriverManager.getConnection(
                fixture.jdbcUrl(), fixture.adminUsername(), fixture.adminCredential());
                var statement = connection.createStatement()) {
            String catalog = connection.getCatalog().replace("`", "``");
            for (String table : java.util.List.of(
                    "auth_account", "auth_credential", "auth_refresh_token", "auth_login_attempt")) {
                statement.execute("GRANT SELECT, INSERT, UPDATE, DELETE ON `" + catalog
                        + "`.`" + table + "` TO '" + appUser + "'@'%'");
            }
        }
    }

    private static long queryCount(java.sql.Connection connection, String table) throws Exception {
        try (var rows = connection.createStatement().executeQuery("SELECT COUNT(*) FROM " + table)) {
            rows.next();
            return rows.getLong(1);
        }
    }

    private static LinkedHashSet<String> tableNames(java.sql.Connection connection) throws Exception {
        var names = new LinkedHashSet<String>();
        try (var rows = connection.getMetaData().getTables(
                connection.getCatalog(), null, "%", new String[] {"TABLE"})) {
            while (rows.next()) {
                names.add(rows.getString("TABLE_NAME").toLowerCase());
            }
        }
        return names;
    }

    private static LinkedHashSet<String> columnNames(
            java.sql.Connection connection, String table) throws Exception {
        var names = new LinkedHashSet<String>();
        try (var rows = connection.getMetaData().getColumns(
                connection.getCatalog(), null, table, "%")) {
            while (rows.next()) {
                names.add(rows.getString("COLUMN_NAME").toLowerCase());
            }
        }
        return names;
    }

    private static LinkedHashSet<String> indexNames(
            java.sql.Connection connection, String table) throws Exception {
        var names = new LinkedHashSet<String>();
        try (var rows = connection.getMetaData().getIndexInfo(
                connection.getCatalog(), null, table, false, false)) {
            while (rows.next()) {
                String name = rows.getString("INDEX_NAME");
                if (name != null) {
                    names.add(name.toLowerCase());
                }
            }
        }
        return names;
    }

    private static LinkedHashSet<String> importedKeyTables(
            java.sql.Connection connection, String table) throws Exception {
        var names = new LinkedHashSet<String>();
        try (var rows = connection.getMetaData().getImportedKeys(
                connection.getCatalog(), null, table)) {
            while (rows.next()) {
                names.add(rows.getString("PKTABLE_NAME").toLowerCase());
            }
        }
        return names;
    }
}
