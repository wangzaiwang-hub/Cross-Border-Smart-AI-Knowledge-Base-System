package com.yuegang.zhihui.tools;

import java.io.IOException;
import java.io.InputStream;
import java.lang.reflect.InvocationTargetException;
import java.lang.reflect.Method;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Properties;

public final class LocalServiceLauncher {
    private static final Map<String, String> MAIN_CLASSES = new LinkedHashMap<>();

    static {
        MAIN_CLASSES.put("system", "com.yuegang.zhihui.system.SystemApplication");
        MAIN_CLASSES.put("user", "com.yuegang.zhihui.user.UserApplication");
        MAIN_CLASSES.put("auth", "com.yuegang.zhihui.auth.AuthApplication");
        MAIN_CLASSES.put("system-migration", "com.yuegang.zhihui.system.SystemMigrationApplication");
        MAIN_CLASSES.put("user-migration", "com.yuegang.zhihui.user.UserMigrationApplication");
        MAIN_CLASSES.put("auth-migration", "com.yuegang.zhihui.auth.AuthMigrationApplication");
    }

    private LocalServiceLauncher() {
    }

    public static void main(String[] args) throws Exception {
        Arguments parsed = Arguments.parse(args);
        if (parsed.help()) {
            printUsage();
            return;
        }

        String mainClassName = MAIN_CLASSES.get(parsed.service());
        if (mainClassName == null) {
            throw new IllegalArgumentException("Unknown service: " + parsed.service()
                    + ". Available: " + MAIN_CLASSES.keySet());
        }

        Path envFile = parsed.envFile();
        if (Files.notExists(envFile)) {
            throw new IllegalArgumentException("Config file does not exist: " + envFile);
        }

        loadProperties(envFile);
        applyRuntimeDefaults(parsed.service());
        invokeMain(mainClassName, parsed.applicationArgs());
    }

    private static void loadProperties(Path file) throws IOException {
        Properties properties = new Properties();
        try (InputStream input = Files.newInputStream(file)) {
            properties.load(input);
        }

        for (String name : properties.stringPropertyNames()) {
            String value = properties.getProperty(name);
            if (value != null && !value.isBlank() && System.getProperty(name) == null) {
                System.setProperty(name, value.trim());
            }
        }
    }

    private static void applyRuntimeDefaults(String service) {
        System.setProperty("spring.main.banner-mode", System.getProperty("spring.main.banner-mode", "console"));
        if (!service.endsWith("-migration")) {
            System.setProperty("spring.flyway.enabled", System.getProperty("spring.flyway.enabled", "false"));
        }
    }

    private static void invokeMain(String mainClassName, String[] args) throws Exception {
        Class<?> mainClass = Class.forName(mainClassName);
        Method main = mainClass.getMethod("main", String[].class);
        try {
            main.invoke(null, (Object) args);
        } catch (InvocationTargetException failure) {
            Throwable cause = failure.getCause();
            if (cause instanceof Exception exception) {
                throw exception;
            }
            if (cause instanceof Error error) {
                throw error;
            }
            throw failure;
        }
    }

    private static void printUsage() {
        System.out.println("Usage: java -cp <runner-and-service-classpath> "
                + LocalServiceLauncher.class.getName()
                + " --env=<external-properties-file> <service>");
        System.out.println("Services: " + MAIN_CLASSES.keySet());
    }

    private record Arguments(String service, Path envFile, String[] applicationArgs, boolean help) {
        static Arguments parse(String[] args) {
            if (args.length == 0 || "--help".equals(args[0]) || "-h".equals(args[0])) {
                return new Arguments("", Path.of(""), new String[0], true);
            }

            Path envFile = Path.of(System.getenv().getOrDefault("YGH_LOCAL_ENV_FILE",
                    "E:/ygh-secrets/env/ygh-core-services.properties"));
            String service = null;
            int serviceIndex = -1;

            for (int i = 0; i < args.length; i++) {
                String arg = args[i];
                if (arg.startsWith("--env=")) {
                    envFile = Path.of(arg.substring("--env=".length()));
                } else if ("--env".equals(arg)) {
                    if (i + 1 >= args.length) {
                        throw new IllegalArgumentException("--env requires a file path");
                    }
                    envFile = Path.of(args[++i]);
                } else {
                    service = arg;
                    serviceIndex = i;
                    break;
                }
            }

            if (service == null) {
                throw new IllegalArgumentException("Missing service name");
            }

            String[] applicationArgs = new String[Math.max(0, args.length - serviceIndex - 1)];
            if (applicationArgs.length > 0) {
                System.arraycopy(args, serviceIndex + 1, applicationArgs, 0, applicationArgs.length);
            }
            return new Arguments(service, envFile, applicationArgs, false);
        }
    }
}
