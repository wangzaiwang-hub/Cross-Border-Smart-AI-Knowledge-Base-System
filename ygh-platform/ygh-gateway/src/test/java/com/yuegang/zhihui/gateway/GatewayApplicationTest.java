package com.yuegang.zhihui.gateway;

import static org.assertj.core.api.Assertions.assertThat;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import org.junit.jupiter.api.Test;
import org.springframework.boot.WebApplicationType;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.builder.SpringApplicationBuilder;
import org.springframework.boot.web.context.reactive.ConfigurableReactiveWebApplicationContext;
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
                .contains("web-application-type: reactive");
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
    }

    @Test
    void gatewayStartsAsReactiveApplicationWithoutExternalInfrastructure() {
        try (var context = new SpringApplicationBuilder(GatewayApplication.class)
                .web(WebApplicationType.REACTIVE)
                .run("--server.port=0")) {
            assertThat(context).isInstanceOf(ConfigurableReactiveWebApplicationContext.class);
            assertThat(context.containsBean("webHandler")).isTrue();
        }
    }
}
