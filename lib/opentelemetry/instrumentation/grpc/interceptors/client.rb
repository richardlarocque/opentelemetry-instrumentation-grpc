# frozen_string_literal: true

module OpenTelemetry
  module Instrumentation
    module Grpc
      module Interceptors
        class Client < ::GRPC::ClientInterceptor
          def request_response(request: nil, call: nil, method: nil, metadata: nil, &blk)
            call(type: 'request_response', requests: [request], call: call, method: method, metadata: metadata, &blk)
          end

          def client_streamer(requests: nil, call: nil, method: nil, metadata: nil, &blk)
            call(type: 'client_streamer', requests: requests, call: call, method: method, metadata: metadata, &blk)
          end

          def server_streamer(request: nil, call: nil, method: nil, metadata: nil, &blk)
            call(type: 'server_streamer', requests: [request], call: call, method: method, metadata: metadata, &blk)
          end

          def bidi_streamer(request: nil, call: nil, method: nil, metadata: nil, &blk)
            call(type: 'client_streamer', requests: requests, call: call, method: method, metadata: metadata, &blk)
          end

          private

          def call(type:, requests: nil, call: nil, method: nil, metadata: nil)
            return yield if instrumentation_config.empty?

            method_parts = method.to_s.split('/')
            service = method_parts[1]
            method_name = method_parts.last
            method_name_with_service = [service.underscore, method].join('.').downcase

            attributes = {
              OpenTelemetry::SemanticConventions::Trace::RPC_SYSTEM => 'grpc',
              OpenTelemetry::SemanticConventions::Trace::RPC_SERVICE => service,
              OpenTelemetry::SemanticConventions::Trace::RPC_METHOD => method,
              OpenTelemetry::SemanticConventions::Trace::PEER_SERVICE => instrumentation_config[:peer_service],
              'rpc.type' => type,
              'net.sock.peer.addr' => call.instance_variable_get(:@wrapped)&.peer
            }.compact

            attributes.merge!(allowed_metadata_headers(metadata.transform_keys(&:to_s)))

            instrumentation_tracer.in_span(
              method.to_s,
              attributes: attributes,
              kind: OpenTelemetry::Trace::SpanKind::CLIENT
            ) do |span|
              OpenTelemetry.propagation.inject(metadata)
              yield.tap do
                span&.set_attribute(OpenTelemetry::SemanticConventions::Trace::RPC_GRPC_STATUS_CODE, 0)
              end
            rescue StandardError => e
              span&.set_attribute(OpenTelemetry::SemanticConventions::Trace::RPC_GRPC_STATUS_CODE, e.code)
              raise e
            end
          end

          def allowed_metadata_headers(metadata)
            instrumentation_config[:allowed_metadata_headers].each_with_object({}) do |k, h|
              if (v = metadata[k.to_s])
                h["rpc.request.metadata.#{k}"] = v
              end
            end
          end

          def instrumentation_config
            Grpc::Instrumentation.instance.config
          end

          def instrumentation_tracer
            Grpc::Instrumentation.instance.tracer
          end
        end
      end
    end
  end
end