package com.yuegang.zhihui.user.api;

import jakarta.validation.constraints.*;

public record UpdateUserProfileRequest(
        @NotBlank @Size(max = 80) String displayName,
        @Size(max = 512) String avatarUrl,
        @NotBlank @Pattern(regexp = "[a-z]{2}(?:-[A-Z]{2})?") String locale,
        @NotBlank @Size(max = 64) String timezone,
        @PositiveOrZero long version
) { }
