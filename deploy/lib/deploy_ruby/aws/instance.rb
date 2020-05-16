require_relative './ec2'

module DeployRuby
  module Aws
    class Instance
      attr_reader :id, :name, :public_ip, :availability_zone, :launched_at

      def initialize(instance)
        @id = instance.id
        @name = instance.tags.find { |t| t.key == 'Name' }&.value
        @public_ip = instance.public_ip_address
        @availability_zone = instance.placement.availability_zone
        @launched_at = instance.launch_time
      end

      def host
        @name
      end

      def terminate
        ::DeployRuby::Aws::EC2.new.terminate_instance(@id)
      end

      class << self
        def retrieve(id)
          new(::DeployRuby::Aws::EC2.new.retrieve_instance(id))
        end

        def retrieve_by(id: nil, name: nil)
          if id
            retrieve(id)
          else
            new(::DeployRuby::Aws::EC2.new.retrieve_instance_by(name: name))
          end
        end
      end
    end
  end
end
