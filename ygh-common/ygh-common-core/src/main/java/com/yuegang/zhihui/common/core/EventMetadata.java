package com.yuegang.zhihui.common.core;

import java.time.OffsetDateTime;

/** Immutable event header shared by transport adapters and business services. */
public record EventMetadata(
        String eventId,
        String eventType,
        int eventVersion,
        OffsetDateTime occurredAt,
        String traceId,
        String producer,
        String businessKey
) {

    public EventMetadata {
        requireText(eventId, "eventId");
        requireText(eventType, "eventType");
        if (!eventType.matches("[A-Z][A-Z0-9_]*")) {
            throw new IllegalArgumentException("eventType must be an uppercase stable code");
        }
        if (eventVersion < 1) {
            throw new IllegalArgumentException("eventVersion must be at least 1");
        }
        if (occurredAt == null) {
            throw new IllegalArgumentException("occurredAt must not be null");
        }
        requireText(traceId, "traceId");
        requireText(producer, "producer");
        requireText(businessKey, "businessKey");
    }

    private static void requireText(String value, String fieldName) {
        if (value == null || value.isBlank()) {
            throw new IllegalArgumentException(fieldName + " must not be blank");
        }
    }
}
