package com.yuegang.zhihui.tests.security;

import static org.junit.jupiter.api.Assertions.assertTrue;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import org.junit.jupiter.api.Test;

class SecurityDeliveryTest {
    private static final Path ROOT = locateReactorRoot();

    private static Path locateReactorRoot() {
        Path current = Path.of(System.getProperty("user.dir")).toAbsolutePath();
        while (current != null && !Files.isRegularFile(current.resolve("mvnw.cmd"))) {
            current = current.getParent();
        }
        if (current == null) {
            throw new IllegalStateException("Unable to locate Maven reactor root from user.dir");
        }
        return current;
    }

    @Test void repositoryDefinesSecretAndDependencyGates() {
        assertTrue(Files.isRegularFile(ROOT.resolve("ygh-deploy/scripts/check-staged-secrets.ps1")));
        assertTrue(Files.isRegularFile(ROOT.resolve("ygh-deploy/scripts/audit-sbom.ps1")));
        assertTrue(Files.isRegularFile(ROOT.resolve(".github/dependabot.yml")));
    }

    @Test void everyJavaRuntimeDropsRootPrivileges() throws IOException {
        try (var files = Files.walk(ROOT)) {
            var dockerfiles = files.filter(path -> path.getFileName().toString().equals("Dockerfile"))
                    .filter(path -> !path.toString().contains("ygh-web")).toList();
            assertTrue(dockerfiles.size() >= 14);
            for (Path dockerfile : dockerfiles) {
                assertTrue(Files.readString(dockerfile).contains("USER 10001:10001"),
                        () -> "runtime does not drop root: " + dockerfile);
            }
        }
    }
}
