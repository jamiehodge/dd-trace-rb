require 'ddtrace/configuration'
require 'ddtrace/configurable'

module Datadog
  class ConfigurationTest < Minitest::Test
    def setup
      @registry = Registry.new
      @configuration = Configuration.new(registry: @registry)
    end

    def test_use_method
      contrib = Minitest::Mock.new
      contrib.expect(:patch, true)
      contrib.expect(:sorted_options, [])

      @registry.add(:example, contrib)
      @configuration.use(:example)

      assert_mock(contrib)
    end

    def test_module_configuration
      integration = Module.new do
        include Contrib::Base
        option :option1
        option :option2
      end

      @registry.add(:example, integration)

      @configuration.use(:example, option1: :foo!, option2: :bar!)

      assert_equal(:foo!, @configuration[:example][:option1])
      assert_equal(:bar!, @configuration[:example][:option2])
    end

    def test_setting_a_configuration_param
      integration = Module.new do
        include Contrib::Base
        option :option1
      end

      @registry.add(:example, integration)
      @configuration[:example][:option1] = :foo
      assert_equal(:foo, @configuration[:example][:option1])
    end

    def test_invalid_integration
      assert_raises(Configuration::InvalidIntegrationError) do
        @configuration[:foobar]
      end
    end

    def test_lazy_option
      integration = Module.new do
        include Contrib::Base
        option :option1, default: -> { 1 + 1 }
      end

      @registry.add(:example, integration)

      assert_equal(2, @configuration[:example][:option1])
    end

    def test_hash_coercion
      integration = Module.new do
        include Contrib::Base
        option :option1, default: :foo
        option :option2, default: :bar
      end

      @registry.add(:example, integration)
      assert_equal({ option1: :foo, option2: :bar }, @configuration[:example].to_h)
    end

    def test_dependency_solving
      integration = Module.new do
        include Contrib::Base
        option :multiply_by, depends_on: [:number] do |value|
          get_option(:number) * value
        end

        option :number
      end

      @registry.add(:example, integration)
      @configuration.use(:example, multiply_by: 5, number: 5)
      assert_equal(5, @configuration[:example][:number])
      assert_equal(25, @configuration[:example][:multiply_by])
    end

    def test_default_also_passes_through_setter
      array = []

      integration = Module.new do
        include Contrib::Base
        option :option1
        option :option2, default: 10 do |value|
          array << value
          value
        end
      end

      @registry.add(:example, integration)
      @configuration.use(:example, option1: :foo!)

      assert_equal(:foo!, @configuration[:example][:option1])
      assert_equal(10, @configuration[:example][:option2])
      assert_includes(array, 10)
    end
  end
end
