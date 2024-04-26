require 'minitest/autorun'
require 'minitest/spec'
require 'async'

require_relative '../lib/vaas/client_credentials_grant_authenticator'
require_relative '../lib/vaas/resource_owner_password_grant_authenticator'
require_relative '../lib/vaas/vaas_main'

# # test locally with .env file (comment this when push)
# require 'dotenv'
# Dotenv.load
# CLIENT_ID = ENV.fetch('CLIENT_ID')
# CLIENT_SECRET = ENV.fetch('CLIENT_SECRET')
# TOKEN_URL = ENV.fetch('TOKEN_URL')
# VAAS_URL = ENV.fetch('VAAS_URL')
# USER_NAME = ENV.fetch('VAAS_USER_NAME')
# PASSWORD = ENV.fetch('VAAS_PASSWORD')

# automatic test (need this when push)
CLIENT_ID = ENV.fetch('CLIENT_ID')
CLIENT_SECRET = ENV.fetch('CLIENT_SECRET')
TOKEN_URL = ENV.fetch('TOKEN_URL')
VAAS_URL = ENV.fetch('VAAS_URL')
USER_NAME = ENV.fetch('VAAS_USER_NAME')
PASSWORD = ENV.fetch('VAAS_PASSWORD')

class VaasTest < Minitest::Test
  TEST_CLASS = self
  describe TEST_CLASS do
    def create(token = nil, timeout = nil)
      authenticator = VAAS::ClientCredentialsGrantAuthenticator.new(
        CLIENT_ID,
        CLIENT_SECRET,
        TOKEN_URL
      )
      token = token || authenticator.get_token
      timeout = timeout || 600
      vaas = VAAS::VaasMain.new(VAAS_URL, timeout)

      return [vaas, token]
    end

    describe 'succeeds' do

      specify 'for_sha256' do
        vaas, token = create
        Async do
          vaas.connect(token)

          result = vaas.for_sha256("ab5788279033b0a96f2d342e5f35159f103f69e0191dd391e036a1cd711791a2")
          verdict = result.wait.verdict
          assert_equal "Malicious", verdict

          vaas.close
        end
      end

      specify 'for_file' do
        vaas, token = create
        Async do
          vaas.connect(token)

          random_text = (0...8).map { (65 + rand(26)).chr }.join
          File.open("test.txt", "w") { |f| f.write(random_text) }
          result = vaas.for_file("./test.txt")
          verdict = result.wait.verdict
          assert_equal "Clean", verdict

          vaas.close
        end
      end

      specify 'for_url' do
        vaas, token = create
        Async do
          vaas.connect(token)

          result = vaas.for_url("https://secure.eicar.org/eicar.com.txt")
          verdict = result.wait.verdict
          assert_equal "Malicious", result.wait.verdict
          assert_empty result.wait.detection

          vaas.close
        end
      end

      specify 'pup' do
        vaas, token = create
        Async do
          vaas.connect(token)

          result = vaas.for_sha256("d6f6c6b9fde37694e12b12009ad11ab9ec8dd0f193e7319c523933bdad8a50ad")
          verdict = result.wait.verdict
          assert_equal "Pup", verdict

          vaas.close
        end
      end

      specify 'for_big_file' do
        skip
        vaas, token = create
        File.open("test.txt", "w") { |file| file.write("\n" * 500000000) }
        Async do
          vaas.connect(token)

          result = vaas.for_file("./test.txt")
          verdict = result.wait.verdict
          assert_equal "Clean", verdict

          vaas.close
        end
      end

      specify 'authenticate' do
        authenticator = VAAS::ResourceOwnerPasswordGrantAuthenticator.new(
          "vaas-customer",
          USER_NAME,
          PASSWORD,
          TOKEN_URL
        )

        token = authenticator.get_token
        refute_nil token
      end
    end

    describe 'fail' do

      specify 'not_connected' do
        vaas = VAAS::VaasMain.new
        assert_raises VAAS::VaasInvalidStateError do
          vaas.for_sha256("ab5788279033b0a96f2d342e5f35159f103f69e0191dd391e036a1cd711791a2").wait
        end
      end

      specify 'not_authenticated' do
        vaas, token = create("invalid token", 600)
        Async do
          assert_raises VAAS::VaasAuthenticationError do
            vaas.connect(token)
          end
          vaas.close
        end
      end

      specify 'connection_closed' do
        vaas, token = create
        Async do
          vaas.connect(token)
          vaas.close
          assert_raises VAAS::VaasConnectionClosedError do
            vaas.for_sha256("ab5788279033b0a96f2d342e5f35159f103f69e0191dd391e036a1cd711791a2").wait
          end
        end
      end

      specify 'timeout' do
        vaas, token = create(nil, 0.001)
        random_text = (0...8).map { (65 + rand(26)).chr }.join
        File.open("test.txt", "w") { |f| f.write(random_text) }
        Async do
          assert_raises VAAS::VaasTimeoutError do
            vaas.connect(token)
            vaas.for_file("./test.txt").wait
          end
        ensure
          vaas.close
        end
      end

      specify 'upload_failed' do
        vaas, token = create
        message = {"url" => "https://upload-vaas.gdatasecurity.de/upload", "upload_token" => "invalid_token"}
        Async do
          random_text = (0...8).map { (65 + rand(26)).chr }.join
          File.open("test.txt", "w") { |f| f.write(random_text) }

          vaas.connect(token)
          assert_raises VAAS::VaasUploadError do
            vaas.upload(message, "./test.txt").wait
          end
        ensure
          vaas.close
        end
      end
    end
  end
end
