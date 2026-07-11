package com.yuegang.zhihui.gateway;

import static org.assertj.core.api.Assertions.assertThat;

import java.io.IOException;
import java.net.URI;
import java.nio.charset.StandardCharsets;
import java.util.Arrays;
import java.util.Map;
import java.util.Set;
import java.util.function.Function;
import java.util.stream.Collectors;
import org.junit.jupiter.api.Test;
import org.springframework.boot.WebApplicationType;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.builder.SpringApplicationBuilder;
import org.springframework.boot.web.context.reactive.ConfigurableReactiveWebApplicationContext;
import org.springframework.cloud.gateway.route.RouteDefinition;
import org.springframework.cloud.gateway.route.RouteDefinitionLocator;
import org.springframework.core.io.ClassPathResource;
import org.springframework.util.ClassUtils;

class GatewayApplicationTest {

    @Test
    void gatewayBootstrapAndConfigurationFollowServiceContract() throws IOException {
        assertThat(GatewayApplication.class.getAnnotation(SpringBootApplication.class)).isNotNull();

        var configuration = new ClassPathResource("application.yml");
        assertThat(configuration.exists()).isTrue();
        assertThat(configuration.getContentAsString(StandardCharsets.UTF_8))
                .contains("name: ygh-gateway")
                .contains("web-application-type: reactive")
                .contains("server-addr: ${YGH_NACOS_SERVER_ADDR}")
                .contains("password: ${YGH_NACOS_PASSWORD}");
    }

    @Test
    void gatewayClasspathIsReactiveAndDoesNotContainSpringMvc() {
        ClassLoader classLoader = GatewayApplicationTest.class.getClassLoader();

        assertThat(ClassUtils.isPresent(
                "org.springframework.web.reactive.DispatcherHandler", classLoader)).isTrue();
        assertThat(ClassUtils.isPresent(
                "org.springframework.web.servlet.DispatcherServlet", classLoader)).isFalse();
        assertThat(ClassUtils.isPresent(
                "jakarta.servlet.Servlet", classLoader)).isFalse();
        assertThat(ClassUtils.isPresent(
                "com.alibaba.cloud.nacos.registry.NacosServiceRegistry", classLoader)).isTrue();
        assertThat(ClassUtils.isPresent(
                "org.springframework.cloud.gateway.filter.ReactiveLoadBalancerClientFilter", classLoader)).isTrue();
        assertThat(ClassUtils.isPresent(
                "com.github.benmanes.caffeine.cache.Caffeine", classLoader)).isTrue();
    }

    @Test
    void gatewayStartsAsReactiveApplicationWithoutExternalInfrastructure() {
        try (var context = new SpringApplicationBuilder(GatewayApplication.class)
                .web(WebApplicationType.REACTIVE)
                .run(
                        "--server.port=0",
                        "--spring.cloud.nacos.discovery.enabled=false",
                        "--spring.cloud.nacos.server-addr=127.0.0.1:1")) {
            assertThat(context).isInstanceOf(ConfigurableReactiveWebApplicationContext.class);
            assertThat(context.containsBean("webHandler")).isTrue();

            var definitions = context.getBean(RouteDefinitionLocator.class)
                    .getRouteDefinitions().collectList().block();
            assertThat(definitions).isNotNull();
            Map<String, RouteDefinition> byId = definitions.stream()
                    .collect(Collectors.toMap(RouteDefinition::getId, Function.identity()));
            assertThat(byId).containsOnlyKeys("auth-service", "user-service", "system-service");
            assertThat(byId.get("auth-service").getUri()).isEqualTo(URI.create("lb://ygh-auth-service"));
            assertThat(byId.get("user-service").getUri()).isEqualTo(URI.create("lb://ygh-user-service"));
            assertThat(byId.get("system-service").getUri()).isEqualTo(URI.create("lb://ygh-system-service"));
            assertRoutePaths(byId.get("auth-service"), Set.of("/api/v1/auth/**"));
            assertRoutePaths(byId.get("user-service"), Set.of(
                    "/api/v1/users/**",
                    "/api/v1/employees/**",
                    "/api/v1/departments/**",
                    "/api/v1/jobs/**",
                    "/api/v1/addresses/**"));
            assertRoutePaths(byId.get("system-service"), Set.of(
                    "/api/v1/system/**",
                    "/api/v1/roles/**",
                    "/api/v1/permissions/**"));
        }
    }

    private static void assertRoutePaths(RouteDefinition route, Set<String> expectedPaths) {
        assertThat(route.getPredicates()).singleElement().satisfies(predicate -> {
            assertThat(predicate.getName()).isEqualTo("Path");
            Set<String> actualPaths = predicate.getArgs().values().stream()
                    .flatMap(value -> Arrays.stream(value.split(",")))
                    .map(String::trim)
                    .collect(Collectors.toSet());
            assertThat(actualPaths).containsExactlyInAnyOrderElementsOf(expectedPaths);
            assertThat(actualPaths).doesNotContain("/api/v1/**");
        });
    }
}
