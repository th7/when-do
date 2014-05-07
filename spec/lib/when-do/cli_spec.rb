require 'spec_helper'
require 'when-do/cli'

describe When::CLI do
  let(:cli) { When::CLI.new }

  describe '#options' do
    context 'argv has an option with no following value' do
      before do
        cli.stub(:argv).and_return(['-option'])
      end

      it 'puts { :option => nil } into the options hash' do
        expect(cli.options[:option]).to eq nil
      end
    end

    context 'argv has an option with one following value' do
      before do
        cli.stub(:argv).and_return(['-option', 'value'])
      end

      it 'puts { :option => "value" } into the options hash' do
        expect(cli.options[:option]).to eq('value')
      end
    end

    context 'argv has an option with several following values' do
      before do
        cli.stub(:argv).and_return(['-option', 'value1', 'value2', 'value3'])
      end

      it 'puts { :option => ["value1", "value2", "value3"] } into the options hash' do
        expect(cli.options[:option]).to eq(['value1', 'value2', 'value3'])
      end
    end

    context 'argv has complex options and values with several following values' do
      before do
        cli.stub(:argv).and_return(['-option1', '-option2', 'value2-1', '-option3', 'value3-1', 'value3-2', 'value3-3'])
      end

      it 'builds the options hash' do
        expect(cli.options[:option1]).to eq(nil)
        expect(cli.options[:option2]).to eq('value2-1')
        expect(cli.options[:option3]).to eq(['value3-1', 'value3-2', 'value3-3'])
      end
    end

    context 'argv includes a path to a config file' do
      context 'but no additional command line options' do
        before do
          cli.stub(:argv).and_return(['-c', 'a file path', '-e', 'test'])
          File.stub(:read).with('a file path').and_return({test: {yaml: 'config'}}.to_yaml)
        end

        it 'adds options from the config file' do
          expect(cli.options[:yaml]).to eq('config')
        end
      end

      context 'and additional command line options' do
        before do
          cli.stub(:argv).and_return(['-c', 'a file path', '-override', 'overridden'])
          File.stub(:read).with('a file path').and_return({override: 'not overridden'}.to_yaml)
        end

        it 'command line arguments override options from the config file' do
          expect(cli.options[:override]).to eq('overridden')
        end
      end
    end

    context 'argv includes a path to a redis config file' do
      before do
        cli.stub(:argv).and_return(['-rc', 'a file path'])
        File.stub(:read).with('a file path').and_return({redis_opt: 'redis opt'}.to_yaml)
      end

      it 'adds options from the redis config file under :redis_opts' do
        expect(cli.options[:redis_opts][:redis_opt]).to eq('redis opt')
      end
    end
  end
end
