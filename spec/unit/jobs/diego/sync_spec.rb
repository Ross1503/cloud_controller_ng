require 'spec_helper'

module VCAP::CloudController
  module Jobs::Diego
    RSpec.describe Sync, job_context: :clock do
      let(:processes_sync) { instance_double(Diego::ProcessesSync) }
      let(:tasks_sync) { instance_double(Diego::ProcessesSync) }
      subject(:job) { Sync.new }

      describe '#perform' do
        before do
          allow(Diego::ProcessesSync).to receive(:new).and_return(processes_sync)
          allow(Diego::TasksSync).to receive(:new).and_return(tasks_sync)

          allow(processes_sync).to receive(:sync)
          allow(tasks_sync).to receive(:sync)
        end

        it 'syncs processes' do
          job.perform
          expect(processes_sync).to have_received(:sync).once
        end

        it 'syncs tasks' do
          job.perform
          expect(tasks_sync).to have_received(:sync).once
        end

        it 'records sync duration' do
          yielded_block = nil

          allow_any_instance_of(Statsd).to receive(:time) do |_, metric_name, &block|
            expect(metric_name).to eq 'cc.diego_sync.duration'
            yielded_block = block
          end

          job.perform
          expect(processes_sync).to_not have_received(:sync)
          expect(tasks_sync).to_not have_received(:sync)

          yielded_block.call
          expect(processes_sync).to have_received(:sync)
          expect(tasks_sync).to have_received(:sync)
        end
      end
    end
  end
end
