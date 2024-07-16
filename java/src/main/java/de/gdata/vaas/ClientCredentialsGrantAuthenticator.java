package de.gdata.vaas;

import com.google.gson.JsonParser;
import lombok.Getter;
import lombok.NonNull;
import org.jetbrains.annotations.NotNull;

import java.io.IOException;
import java.io.UnsupportedEncodingException;
import java.net.URI;
import java.net.URISyntaxException;
import java.net.URLEncoder;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.util.HashMap;
import java.util.Map;
import java.util.stream.Collectors;

@Getter
public class ClientCredentialsGrantAuthenticator implements IAuthenticator {

    private final String clientId;
    private final String clientSecret;

    @NonNull
    private final URI tokenEndpoint;

    private final HttpClient httpClient;

    public ClientCredentialsGrantAuthenticator(String clientId, String clientSecret, @NotNull URI tokenEndpoint, boolean ignoreTlsErrors) {
        this.tokenEndpoint = tokenEndpoint;
        this.clientId = clientId;
        this.clientSecret = clientSecret;

        var httpClientBuilder = HttpClient.newBuilder();

        var sslContext = SSLContextFactory.create(ignoreTlsErrors);
        if (sslContext != null) {
            httpClientBuilder.sslContext(sslContext);
        }

        httpClient = httpClientBuilder.build();
    }

    public ClientCredentialsGrantAuthenticator(String clientId, String clientSecret)
            throws URISyntaxException {
        this(clientId, clientSecret, new URI("https://account.gdata.de/realms/vaas-production/protocol/openid-connect/token"), false);
    }

    private String encodeValue(String value) throws UnsupportedEncodingException {
        return URLEncoder.encode(value, StandardCharsets.UTF_8);
    }

    public String getToken() throws IOException, InterruptedException {
        Map<String, String> requestParams = new HashMap<>();
        requestParams.put("client_id", this.clientId);
        requestParams.put("grant_type", "client_credentials");
        requestParams.put("client_secret", this.clientSecret);
        var uriWithParameters = requestParams.keySet().stream()
                .map(key -> {
                    try {
                        return key + "=" + encodeValue(requestParams.get(key));
                    } catch (UnsupportedEncodingException e) {
                        return "";
                    }
                })
                .collect(Collectors.joining("&"));
        var request = HttpRequest
                .newBuilder(tokenEndpoint)
                .header("Content-Type", "application/x-www-form-urlencoded")
                .POST(HttpRequest.BodyPublishers.ofString(uriWithParameters))
                .build();

        var response = httpClient
                .send(request, HttpResponse.BodyHandlers.ofString());

        if (response.statusCode() != 200) {
            throw new IOException("Failed to upload file. HTTP Status Code: " + response.statusCode() + " Error: "
                    + response.body());
        }
        var bodyJsonObject = JsonParser.parseString(response.body()).getAsJsonObject();
        var tokenJsonElement = bodyJsonObject.get("access_token");
        return tokenJsonElement.getAsString();
    }
}
