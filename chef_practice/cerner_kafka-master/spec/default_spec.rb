require 'spec_helper'

describe 'cerner_kafka::default' do

  let(:chef_run) do
    ChefSpec::SoloRunner.new do |node|
      node.set['kafka']['brokers'] = ['chefspec']
      node.set['kafka']['zookeepers'] = ['localhost:2181']
    end
  end

# Changed to v1.0.2
  context 'with version set to 1.0.2' do

    let(:chef_run) do
      ChefSpec::SoloRunner.new do |node|
        node.set['kafka']['brokers'] = ['chefspec']
        node.set['kafka']['zookeepers'] = ['localhost:2181']
        node.set['kafka']['version'] = '1.0.2'
      end
    end

    before(:each) do
      chef_run.converge(described_recipe)
    end

    it 'should overwrite kafka-server-start.sh' do
      expect(chef_run).to create_template('/opt/kafka/bin/kafka-server-stop.sh')
    end

    it 'should overwrite kafka-server-stop.sh'  do
      expect(chef_run).to create_template('/opt/kafka/bin/kafka-server-stop.sh')
    end

  end

# Change to v1.0.2
  context 'with version set to 1.0.2' do

    let(:chef_run) do
      ChefSpec::SoloRunner.new do |node|
        node.set['kafka']['brokers'] = ['chefspec']
        node.set['kafka']['zookeepers'] = ['localhost:2181']
        node.set['kafka']['version'] = '1.0.2'
      end
    end

    before(:each) do
      chef_run.converge(described_recipe)
    end

    it 'should overwrite kafka-server-start.sh' do
      expect(chef_run).to create_template('/opt/kafka/bin/kafka-server-stop.sh')
    end

    it 'should overwrite kafka-server-stop.sh'  do
      expect(chef_run).to create_template('/opt/kafka/bin/kafka-server-stop.sh')
    end

  end

  # Change to 1.0.2
  context 'with version set to 1.0.2' do

    let(:chef_run) do
      ChefSpec::SoloRunner.new do |node|
        node.set['kafka']['brokers'] = ['chefspec']
        node.set['kafka']['zookeepers'] = ['localhost:2181']
        node.set['kafka']['version'] = '1.0.2'
      end
    end

    before(:each) do
      chef_run.converge(described_recipe)
    end

    it 'should not overwrite kafka-server-start.sh' do
      expect(chef_run).not_to create_template('/opt/kafka/bin/kafka-server-stop.sh')
    end

    it 'should not overwrite kafka-server-stop.sh'  do
      expect(chef_run).not_to create_template('/opt/kafka/bin/kafka-server-stop.sh')
    end

  end

  context 'with log.dirs set to many directories' do

    # change to v 1.0.2
    let(:chef_run) do
      ChefSpec::SoloRunner.new do |node|
        node.set['kafka']['brokers'] = ['chefspec']
        node.set['kafka']['zookeepers'] = ['localhost:2181']
        node.set['kafka']['version'] = '1.0.2'
        node.set['kafka']['server.properties']['log.dirs'] = '/tmp/k1,/tmp/k2,/tmp/k3'
      end
    end

    it 'should create a directory for each log.dirs value' do
      chef_run.converge(described_recipe)
      expect(chef_run).to create_directory('/tmp/k1')
      expect(chef_run).to create_directory('/tmp/k2')
      expect(chef_run).to create_directory('/tmp/k3')
    end

  end

  context 'without log.dirs set' do

    # change to 1.0.2
    let(:chef_run) do
      ChefSpec::SoloRunner.new do |node|
        node.set['kafka']['brokers'] = ['chefspec']
        node.set['kafka']['zookeepers'] = ['localhost:2181']
        node.set['kafka']['version'] = '1.0.2'
        node.set['kafka']['server.properties'] = {}
      end
    end

    it 'should not create any log.dirs directory' do
      chef_run.converge(described_recipe)
      expect(chef_run).to_not create_directory('/tmp/k1')
      expect(chef_run).to_not create_directory('/tmp/k2')
      expect(chef_run).to_not create_directory('/tmp/k3')
    end

  end

end
