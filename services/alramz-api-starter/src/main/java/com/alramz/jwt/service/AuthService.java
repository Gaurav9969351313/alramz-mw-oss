package com.alramz.jwt.service;

import com.alramz.jwt.model.RefreshToken;
import com.alramz.jwt.model.TokenPair;
import com.alramz.jwt.model.User;
import com.alramz.jwt.repository.RefreshTokenRepositoryOps;
import com.alramz.jwt.repository.UserRepositoryOps;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.stereotype.Service;

import java.time.Instant;
import java.util.List;

@Service
public class AuthService {

    private static final Logger logger = LoggerFactory.getLogger(AuthService.class);

    private final UserRepositoryOps userRepository;
    private final PasswordEncoderService passwordEncoder;
    private final TokenProvider tokenProvider;
    private final RefreshTokenRepositoryOps refreshTokenRepository;

    public AuthService(UserRepositoryOps userRepository,
                       PasswordEncoderService passwordEncoder,
                       TokenProvider tokenProvider,
                       RefreshTokenRepositoryOps refreshTokenRepository) {
        this.userRepository = userRepository;
        this.passwordEncoder = passwordEncoder;
        this.tokenProvider = tokenProvider;
        this.refreshTokenRepository = refreshTokenRepository;
    }

    public TokenPair login(String username, String password) {
        User user = userRepository.findByUsername(username)
                .orElseThrow(() -> {
                    logger.warn("Login failed: user '{}' not found", username);
                    return new BadCredentialsException("Invalid username or password");
                });

        if (!passwordEncoder.matches(password, user.password())) {
            logger.warn("Login failed: invalid password for user '{}'", username);
            throw new BadCredentialsException("Invalid username or password");
        }

        if (!user.enabled()) {
            logger.warn("Login failed: account disabled for user '{}'", username);
            throw new BadCredentialsException("Account is disabled");
        }

        logger.info("User '{}' logged in successfully with application={}, environment={}", username, user.application(), user.environment());

        TokenPair tokenPair = tokenProvider.generateTokenPair(
                username,
                user.roles(),
                user.application(),
                user.environment()
        );

        RefreshToken refreshToken = new RefreshToken(
                null,
                tokenPair.refreshToken(),
                username,
                Instant.now().plusSeconds(7 * 24 * 60 * 60),
                Instant.now(),
                false
        );
        refreshTokenRepository.save(refreshToken);

        return tokenPair;
    }

    public TokenPair register(String username, String email, String password, List<String> roles, String application, String environment) {
        if (userRepository.existsByUsername(username)) {
            throw new IllegalArgumentException("Username already exists");
        }
        if (userRepository.existsByEmail(email)) {
            throw new IllegalArgumentException("Email already exists");
        }

        String encodedPassword = passwordEncoder.encode(password);
        User user = new User(null, username, email, encodedPassword, roles, true, application, environment);
        User savedUser = userRepository.save(user);

        logger.info("User '{}' registered successfully with application={}, environment={}, roles={}", username, application, environment, roles);

        return tokenProvider.generateTokenPair(savedUser.username(), savedUser.roles(), savedUser.application(), savedUser.environment());
    }

    public void logout(String refreshToken) {
        refreshTokenRepository.revoke(refreshToken);
        logger.info("Refresh token revoked successfully");
    }

    public TokenPair refresh(String refreshToken) {
        RefreshToken storedToken = refreshTokenRepository.findByToken(refreshToken)
                .orElseThrow(() -> {
                    logger.warn("Token refresh failed: invalid refresh token");
                    return new IllegalArgumentException("Invalid refresh token");
                });

        if (storedToken.revoked() || storedToken.expiresAt().isBefore(Instant.now())) {
            logger.warn("Token refresh failed: refresh token expired or revoked for user '{}'", storedToken.userId());
            throw new IllegalArgumentException("Refresh token expired or revoked");
        }

        refreshTokenRepository.revoke(refreshToken);

        User user = userRepository.findByUsername(storedToken.userId())
                .orElseThrow(() -> {
                    logger.error("Token refresh failed: user '{}' not found", storedToken.userId());
                    return new IllegalArgumentException("User not found");
                });

        logger.info("Token refreshed successfully for user '{}'", storedToken.userId());

        TokenPair tokenPair = tokenProvider.generateTokenPair(
                user.username(),
                user.roles(),
                user.application(),
                user.environment()
        );

        RefreshToken newRefreshToken = new RefreshToken(
                null,
                tokenPair.refreshToken(),
                storedToken.userId(),
                Instant.now().plusSeconds(7 * 24 * 60 * 60),
                Instant.now(),
                false
        );
        refreshTokenRepository.save(newRefreshToken);

        return tokenPair;
    }
}
