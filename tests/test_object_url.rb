require 'minitest/autorun'
require 'yaml'
$LOAD_PATH.unshift(File.expand_path("../../lib", __FILE__))
require 'aliyun/oss'
require 'aliyun/sts'
require 'rest-client'
require_relative 'config'

class TestObjectUrl < Minitest::Test
  def setup
    AliyunOss::Common::Logging.set_log_level(Logger::DEBUG)
    client = AliyunOss::OSS::Client.new(TestConf.creds)
    @bucket = client.get_bucket(TestConf.bucket)

    @prefix = "tests/object_url/"
  end

  def get_key(k)
    "#{@prefix}#{k}"
  end

  def test_signed_url_for_get
    key = get_key('object-for-get')

    @bucket.put_object(key, acl: AliyunOss::OSS::ACL::PRIVATE)

    plain_url = @bucket.object_url(key, false)
    begin
      r = RestClient.get(plain_url)
      assert false, 'GET plain object url should receive 403'
    rescue => e
      assert_equal 403, e.response.code
    end

    signed_url = @bucket.object_url(key)
    r = RestClient.get(signed_url)

    assert_equal 200, r.code
  end

  def test_signed_url_with_sts
    key = get_key('object-with-sts')

    sts_client = AliyunOss::STS::Client.new(TestConf.sts_creds)
    token = sts_client.assume_role(TestConf.sts_role, 'app')

    bucket = AliyunOss::OSS::Client.new(
      :endpoint => TestConf.creds[:endpoint],
      :sts_token => token.security_token,
      :access_key_id => token.access_key_id,
      :access_key_secret => token.access_key_secret)
             .get_bucket(TestConf.sts_bucket)

    bucket.put_object(key, acl: AliyunOss::OSS::ACL::PRIVATE)

    plain_url = bucket.object_url(key, false)
    begin
      r = RestClient.get(plain_url)
      assert false, 'GET plain object url should receive 403'
    rescue => e
      assert_equal 403, e.response.code
    end

    signed_url = bucket.object_url(key)
    r = RestClient.get(signed_url)

    assert_equal 200, r.code
  end
end
