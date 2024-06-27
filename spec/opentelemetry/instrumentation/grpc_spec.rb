# frozen_string_literal: true

RSpec.describe OpenTelemetry::Instrumentation::Grpc do
  it "has a version number" do
    expect(OpenTelemetry::Instrumentation::Grpc::VERSION).not_to be nil
  end

  describe ".client_interceptor" do
    it { expect(described_class.client_interceptor).to be_a(OpenTelemetry::Instrumentation::Grpc::Interceptors::Client) }
  end
end
