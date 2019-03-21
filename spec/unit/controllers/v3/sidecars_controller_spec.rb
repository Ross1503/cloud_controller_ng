require 'rails_helper'
require 'permissions_spec_helper'

RSpec.describe SidecarsController, type: :controller do
  let!(:app_model) { VCAP::CloudController::AppModel.make(space: space) }
  let(:user) { VCAP::CloudController::User.make }
  let!(:org) { FactoryBot.create(:organization, name: 'Lyle\'s Farm') }
  let!(:space) { FactoryBot.create(:space, name: 'Cat', organization: org) }

  before do
    set_current_user(user)
    set_current_user_as_role(role: :space_developer, org: org, user: user, space: space)
  end

  describe '#create' do
    let(:sidecar_name) { 'sidecar_one' }
    let(:sidecar_params) {
      {
        guid: app_model.guid,
        name: sidecar_name,
        command: 'bundle exec rackup',
        process_types: ['web', 'other_worker']
      }
    }

    it 'creates a sidecar for a process' do
      expect {
        post :create, params: sidecar_params, as: :json
      }.to change { VCAP::CloudController::SidecarModel.count }.by(1)

      sidecar = VCAP::CloudController::SidecarModel.last

      expect(response.status).to eq 201

      expected_response = {
        'guid' => sidecar.guid,
        'name' => 'sidecar_one',
        'command' => 'bundle exec rackup',
        'process_types' => ['other_worker', 'web'],
        'created_at' => iso8601,
        'updated_at' => iso8601,
        'relationships' => {
          'app' => {
            'data' => {
              'guid' => app_model.guid
            }
          }
        }
      }
      expect(parsed_body).to be_a_response_like(expected_response)
    end

    context 'when the user does not have read permissions on the app space' do
      before do
        disallow_user_read_access(user, space: space)
      end

      it 'returns a 404 ResourceNotFound' do
        post :create, params: sidecar_params, as: :json

        expect(response.status).to eq 404
        expect(response.body).to include 'ResourceNotFound'
      end
    end

    describe 'permissions by role' do
      role_to_expected_http_response = {
          'admin'               => 201,
          'space_developer'     => 201,
          'global_auditor'      => 403,
          'space_manager'       => 403,
          'space_auditor'       => 403,
          'org_manager'         => 403,
          'admin_read_only'     => 403,
          'org_auditor'         => 404,
          'org_billing_manager' => 404,
          'org_user'            => 404,
      }.freeze

      role_to_expected_http_response.each do |role, expected_return_value|
        context "as an #{role}" do
          let(:new_user) { VCAP::CloudController::User.make }

          before do
            set_current_user(new_user)
          end

          it "returns #{expected_return_value}" do
            set_current_user_as_role(role: role, org: org, user: new_user, space: space)

            post :create, params: sidecar_params, as: :json

            expect(response.status).to eq expected_return_value
          end
        end
      end
    end

    describe 'when attempting to create a sidecar with duplicate name' do
      let(:sidecar_name) { 'my_sidecar' }
      let!(:sidecar) { FactoryBot.create(:sidecar, name: 'my_sidecar', app: app_model) }

      it 'returns 422' do
        post :create, params: sidecar_params, as: :json
        expect(response.status).to eq 422
        expect(response.body).to include 'UnprocessableEntity'
        expect(response.body).to include 'Sidecar with name \'my_sidecar\' already exists for given app'
      end
    end

    describe 'when app does not exist' do
      it 'returns 404' do
        sidecar_params[:guid] = '1234'
        post :create, params: sidecar_params, as: :json
        expect(response.status).to eq 404
      end
    end
  end
end