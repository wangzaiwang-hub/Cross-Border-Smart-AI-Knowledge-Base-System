package com.yuegang.zhihui.gateway;

import java.util.Objects;
import java.util.Set;
import java.util.regex.Pattern;
import org.springframework.core.Ordered;
import org.springframework.core.io.buffer.DataBuffer;
import org.springframework.core.io.buffer.DataBufferLimitException;
import org.springframework.core.io.buffer.DataBufferUtils;
import org.springframework.http.HttpMethod;
import org.springframework.http.MediaType;
import org.springframework.http.server.reactive.ServerHttpRequestDecorator;
import org.springframework.web.server.ServerWebExchange;
import org.springframework.web.server.WebFilter;
import org.springframework.web.server.WebFilterChain;
import reactor.core.publisher.Flux;
import reactor.core.publisher.Mono;

/** Rejects unbounded bodies and prevents multipart uploads on undeclared API paths. */
final class GatewayRequestGuardFilter implements WebFilter, Ordered {

    static final long MAX_CONFIGURABLE_BYTES = 100L * 1024 * 1024;
    private static final Pattern SAFE_UPLOAD_PATH = Pattern.compile("/api/v1/[A-Za-z0-9/_-]+");

    private final long requestMaxBytes;
    private final long uploadMaxBytes;
    private final Set<String> uploadPaths;
    private final GatewaySecurityErrorWriter errorWriter;

    GatewayRequestGuardFilter(
            long requestMaxBytes,
            long uploadMaxBytes,
            Set<String> uploadPaths,
            GatewaySecurityErrorWriter errorWriter) {
        if (requestMaxBytes <= 0 || requestMaxBytes > MAX_CONFIGURABLE_BYTES) {
            throw new IllegalArgumentException("requestMaxBytes is outside the safe range");
        }
        if (uploadMaxBytes < requestMaxBytes || uploadMaxBytes > MAX_CONFIGURABLE_BYTES) {
            throw new IllegalArgumentException("uploadMaxBytes is outside the safe range");
        }
        if (uploadPaths == null || uploadPaths.isEmpty()
                || uploadPaths.stream().anyMatch(path -> !isSafeUploadPath(path))) {
            throw new IllegalArgumentException("uploadPaths must contain only exact safe API paths");
        }
        this.requestMaxBytes = requestMaxBytes;
        this.uploadMaxBytes = uploadMaxBytes;
        this.uploadPaths = Set.copyOf(uploadPaths);
        this.errorWriter = Objects.requireNonNull(errorWriter, "errorWriter must not be null");
    }

    @Override
    public Mono<Void> filter(ServerWebExchange exchange, WebFilterChain chain) {
        boolean multipart = exchange.getRequest().getHeaders().getContentType() != null
                && MediaType.MULTIPART_FORM_DATA.isCompatibleWith(
                        exchange.getRequest().getHeaders().getContentType());
        String path = exchange.getRequest().getPath().pathWithinApplication().value();
        boolean allowedUpload = multipart
                && HttpMethod.POST.equals(exchange.getRequest().getMethod())
                && uploadPaths.contains(path);
        if (multipart && !allowedUpload) {
            return errorWriter.uploadPathRejected(exchange);
        }

        long contentLength = exchange.getRequest().getHeaders().getContentLength();
        if (allowedUpload && contentLength < 0) {
            return errorWriter.lengthRequired(exchange);
        }
        long limit = allowedUpload ? uploadMaxBytes : requestMaxBytes;
        if (contentLength > limit) {
            return errorWriter.payloadTooLarge(exchange);
        }
        if (contentLength >= 0) {
            return chain.filter(exchange);
        }

        return DataBufferUtils.join(exchange.getRequest().getBody(), Math.toIntExact(limit))
                .singleOptional()
                .flatMap(buffer -> replay(exchange, chain, buffer.orElse(null)))
                .onErrorResume(DataBufferLimitException.class,
                        ignored -> errorWriter.payloadTooLarge(exchange));
    }

    @Override
    public int getOrder() {
        return Ordered.HIGHEST_PRECEDENCE + 15;
    }

    private static boolean isSafeUploadPath(String path) {
        return path != null && SAFE_UPLOAD_PATH.matcher(path).matches()
                && !path.contains("//") && !path.endsWith("/");
    }

    private static Mono<Void> replay(
            ServerWebExchange exchange, WebFilterChain chain, DataBuffer bufferedBody) {
        var guardedRequest = new ServerHttpRequestDecorator(exchange.getRequest()) {
            @Override
            public Flux<DataBuffer> getBody() {
                if (bufferedBody == null) {
                    return Flux.empty();
                }
                return Flux.defer(() -> Flux.just(DataBufferUtils.retain(bufferedBody)));
            }
        };
        Mono<Void> result = Mono.defer(() ->
                chain.filter(exchange.mutate().request(guardedRequest).build()));
        if (bufferedBody == null) {
            return result;
        }
        return result.doFinally(ignored -> DataBufferUtils.release(bufferedBody));
    }
}
