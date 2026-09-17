package com.alramz.service.impl;

import com.alramz.config.EmailProperties;
import com.alramz.exception.EmailConfigurationException;
import com.alramz.exception.EmailServiceException;
import com.alramz.exception.EmailValidationException;
import com.alramz.model.EmailAttachment;
import com.alramz.model.EmailRequest;
import com.alramz.model.EmailSendResponse;
import com.alramz.service.EmailService;
import com.microsoft.graph.models.BodyType;
import com.microsoft.graph.models.EmailAddress;
import com.microsoft.graph.models.FileAttachment;
import com.microsoft.graph.models.ItemBody;
import com.microsoft.graph.models.Message;
import com.microsoft.graph.models.Recipient;
import com.microsoft.graph.models.UserSendMailParameterSet;
import com.microsoft.graph.requests.AttachmentCollectionPage;
import com.microsoft.graph.requests.GraphServiceClient;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.stereotype.Service;
import org.springframework.util.ObjectUtils;

import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

@Service
public class EmailServiceImpl implements EmailService {

    private static final Logger LOG = LoggerFactory.getLogger(EmailServiceImpl.class);
    private static final String PROVIDER = "MICROSOFT_GRAPH";

    private final EmailProperties emailProperties;
    private final org.springframework.beans.factory.ObjectProvider<GraphServiceClient<?>> graphClientProvider;

    public EmailServiceImpl(
            EmailProperties emailProperties,
            @Qualifier("graphServiceClient") org.springframework.beans.factory.ObjectProvider<GraphServiceClient<?>> graphClientProvider
    ) {
        this.emailProperties = emailProperties;
        this.graphClientProvider = graphClientProvider;
    }

    @Override
    public EmailSendResponse sendEmail(EmailRequest request) {
        validateRequest(request);

        UUID correlationId = UUID.randomUUID();
        UUID traceId = UUID.randomUUID();

        GraphServiceClient<?> graphClient = graphClientProvider.getIfAvailable(); // NOPMD LawOfDemeter
        if (graphClient == null) {
            throw new EmailConfigurationException("Preferred email service provider not configured");
        }

        try {
            Message message = buildGraphMessage(request);
            graphClient.users(request.getFrom()) // NOPMD LawOfDemeter
                    .sendMail(UserSendMailParameterSet.newBuilder()
                            .withMessage(message)
                            .withSaveToSentItems(false)
                            .build())
                    .buildRequest()
                    .post();

            EmailSendResponse response = new EmailSendResponse();
            response.setCorrelationID(correlationId);
            response.setStatus("SUCCESS");
            response.setResponseCode("200");
            response.setResponseMessage("OK");
            response.setProvider(PROVIDER);
            response.setSentTo(request.getTo());
            response.setSentAt(java.time.OffsetDateTime.now());
            response.setTraceId(traceId);
            return response;

        } catch (Exception ex) { // NOPMD AvoidCatchingGenericException
            logEmailError(ex);
            throw new EmailServiceException(503, "Service Unavailable", ex);
        }
    }

    private void validateRequest(EmailRequest request) {
        validateRequiredFields(request);
        validateEmailFormats(request);
        validateFieldLengths(request);
        validateAttachments(request);
    }

    private void validateRequiredFields(EmailRequest request) {
        if (ObjectUtils.isEmpty(request.getTo())) {
            throw new EmailValidationException("400", "Missing or invalid required field: to");
        }
        if (ObjectUtils.isEmpty(request.getSubject())) {
            throw new EmailValidationException("400", "Missing or invalid required field: subject");
        }
        if (ObjectUtils.isEmpty(request.getFrom())) {
            throw new EmailValidationException("400", "Missing or invalid required field: from");
        }
        if (ObjectUtils.isEmpty(request.getBody())) {
            throw new EmailValidationException("400", "Missing or invalid required field: body");
        }
    }

    private void validateEmailFormats(EmailRequest request) {
        if (!isValidEmail(request.getTo())) {
            throw new EmailValidationException("400", "Invalid Email Format");
        }
        if (!isValidEmail(request.getFrom())) {
            throw new EmailValidationException("400", "Invalid Email Format");
        }
    }

    private void validateFieldLengths(EmailRequest request) {
        if (request.getSubject() != null && request.getSubject().length() > emailProperties.maxSubjectLength()) {
            throw new EmailValidationException("400", "Invalid Subject Length");
        }
        if (request.getBody() != null && request.getBody().length() > emailProperties.maxBodyLength()) {
            throw new EmailValidationException("400", "Invalid Body Length");
        }
    }

    private void validateAttachments(EmailRequest request) {
        List<EmailAttachment> attachments = request.getAttachments();
        if (!attachments.isEmpty()) {
            if (attachments.size() > emailProperties.maxAttachments()) {
                throw new EmailValidationException("400", "Invalid Attachment Count");
            }
            for (EmailAttachment attachment : attachments) {
                long sizeBytes = attachment.getContent().length;
                if (sizeBytes > emailProperties.maxAttachmentSizeBytes()) {
                    throw new EmailValidationException("400", "Invalid Attachment Size");
                }
            }
        }
    }

    private Message buildGraphMessage(EmailRequest request) {
        Message message = new Message();
        message.subject = request.getSubject();

        ItemBody body = new ItemBody();
        body.contentType = BodyType.HTML; // NOPMD LawOfDemeter
        body.content = request.getBody();
        message.body = body; // NOPMD LawOfDemeter

        Recipient toRecipient = new Recipient();
        EmailAddress toAddress = new EmailAddress();
        toAddress.address = request.getTo();
        toRecipient.emailAddress = toAddress; // NOPMD LawOfDemeter
        message.toRecipients = List.of(toRecipient); // NOPMD LawOfDemeter

        List<EmailAttachment> attachments = request.getAttachments();
        if (!attachments.isEmpty()) {
            List<com.microsoft.graph.models.Attachment> graphAttachments = new ArrayList<>();
            for (EmailAttachment attachment : attachments) {
                FileAttachment fileAttachment = new FileAttachment();
                fileAttachment.name = attachment.getName();
                fileAttachment.contentBytes = attachment.getContent(); // NOPMD LawOfDemeter
                fileAttachment.size = attachment.getContent().length;
                graphAttachments.add(fileAttachment);
            }
            message.attachments = new AttachmentCollectionPage(graphAttachments, null); // NOPMD LawOfDemeter
        }

        return message;
    }

    private boolean isValidEmail(String email) {
        if (email == null || email.isBlank()) {
            return false;
        }
        String regex = "^[A-Za-z0-9+_.-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$";
        return email.matches(regex);
    }

    private void logEmailError(Exception ex) {
        if (ex instanceof com.microsoft.graph.http.GraphServiceException gse) {
            com.microsoft.graph.http.GraphError serviceError = gse.getServiceError();
            if (LOG.isErrorEnabled()) {
                LOG.error("Graph Error {} - Code: {}, Message: {}", gse.getResponseCode(),
                    serviceError != null ? serviceError.code : "N/A",
                    serviceError != null ? serviceError.message : "N/A", gse);
            }
        } else {
            if (LOG.isErrorEnabled()) {
                LOG.error("Email send failed", ex);
            }
        }
    }
}
