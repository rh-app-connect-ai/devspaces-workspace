//DEPS software.amazon.awssdk:s3-transfer-manager:2.29.51

import org.apache.camel.BindToRegistry;
import org.apache.camel.Exchange;
import org.apache.camel.Processor;
import org.apache.camel.PropertyInject;
import org.apache.camel.builder.RouteBuilder;

import software.amazon.awssdk.services.s3.presigner.S3Presigner;

import software.amazon.awssdk.services.s3.presigner.model.GetObjectPresignRequest;
import software.amazon.awssdk.services.s3.model.GetObjectRequest;
import software.amazon.awssdk.auth.credentials.StaticCredentialsProvider;
import software.amazon.awssdk.auth.credentials.AwsBasicCredentials;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.s3.S3Configuration;
import java.net.URI;
import java.time.Duration;

public class s3Presigner extends RouteBuilder {

    @Override
    public void configure() throws Exception {
        // Routes are loaded from YAML files
    }

    private static String S3_ENDPOINT;
    private static String S3_ACCESS_KEY;
    private static String S3_SECRET_KEY;

    @PropertyInject("s3.presigner.uri")
    public void setS3Endpoint(String url) {
        S3_ENDPOINT = url;
    }

    public static String getS3Endpoint() {
        return S3_ENDPOINT;
    }

    @PropertyInject("s3.presigner.access-key")
    public void setS3AccessKey(String key) {
        S3_ACCESS_KEY = key;
    }

    public static String getS3AccessKey() {
        return S3_ACCESS_KEY;
    }


    @PropertyInject("s3.presigner.secret-key")
    public void setS3SecretKey(String key) {
        S3_SECRET_KEY = key;
    }

    public static String getS3SecretKey() {
        return S3_SECRET_KEY;
    }

    @BindToRegistry(lazy=true)
    public static S3Presigner presigner(){

        S3Presigner presigner = S3Presigner.builder()
            .endpointOverride(URI.create(getS3Endpoint()))
            .serviceConfiguration(S3Configuration.builder()
                .pathStyleAccessEnabled(true)           // ← key setting
                .build())
            .credentialsProvider(StaticCredentialsProvider.create(
                AwsBasicCredentials.create(getS3AccessKey(), getS3SecretKey())))
            .region(Region.US_EAST_1)
            .build();

        return presigner;
    }

}
