require 'spec_helper'

describe 'Any class which includes SimpleTokenAuthentication::TokenAuthenticationHandler' do

  let(:described_class) do
    define_dummy_class_which_includes SimpleTokenAuthentication::TokenAuthenticationHandler
  end

  after(:each) do
    # ensure_examples_independence
    SimpleTokenAuthentication.send(:remove_const, :SomeClass)
  end

  it_behaves_like 'a token authentication handler', lambda { described_class.new }

  let(:subject) { described_class }

  describe '.handle_token_authentication_for' do

    before(:each) do
      double_user_model
    end

    it 'ensures token authentication is handled for a given (token authenticatable) model', public: true do
      entities_manager = double()
      allow(entities_manager).to receive(:find_or_create_entity).and_return('entity')

      # skip steps which are not relevant in this example
      allow(SimpleTokenAuthentication).to receive(:fallback).and_return('default')
      allow(subject).to receive(:entities_manager).and_return(entities_manager)
      allow(subject).to receive(:set_token_authentication_hooks)
      allow(subject).to receive(:define_token_authentication_helpers_for)

      expect(subject).to receive(:set_token_authentication_hooks).with('entity', {option: 'value', fallback: 'default'})
      subject.handle_token_authentication_for(User, {option: 'value'})
    end

    context 'when called multiple times' do

      it 'ensures token authentication is handled for the given (token authenticatable) models', public: true do
        double_super_admin_model
        entities_manager = double()
        allow(entities_manager).to receive(:find_or_create_entity).with(User, nil).and_return('User entity')
        allow(entities_manager).to receive(:find_or_create_entity).with(SuperAdmin, nil).and_return('SuperAdmin entity')

        # skip steps which are not relevant in this example
        allow(SimpleTokenAuthentication).to receive(:fallback).and_return('default')
        allow(subject).to receive(:entities_manager).and_return(entities_manager)
        allow(subject).to receive(:set_token_authentication_hooks)
        allow(subject).to receive(:define_token_authentication_helpers_for)

        expect(subject).to receive(:set_token_authentication_hooks).with('User entity', {option: 'value', fallback: 'default'})
        expect(subject).to receive(:set_token_authentication_hooks).with('SuperAdmin entity', {option: 'some specific value', fallback: 'default'})
        subject.handle_token_authentication_for(User, {option: 'value'})
        subject.handle_token_authentication_for(SuperAdmin, {option: 'some specific value'})
      end
    end

    context 'when an alias is provided for the model', token_authenticatable_aliases_option: true do

      it 'creates an Entity with that alias', private: true do
        entities_manager = double()
        allow(entities_manager).to receive(:find_or_create_entity)

        # skip steps which are not relevant in this example
        allow(subject).to receive(:entities_manager).and_return(entities_manager)
        allow(subject).to receive(:set_token_authentication_hooks)
        allow(subject).to receive(:define_token_authentication_helpers_for)

        expect(entities_manager).to receive(:find_or_create_entity).with(User, 'some_alias')
        subject.handle_token_authentication_for(User, {option: 'value', as: 'some_alias'})
        expect(entities_manager).to receive(:find_or_create_entity).with(User, 'another_alias')
        subject.handle_token_authentication_for(User, {option: 'value', 'as' => 'another_alias'})
      end
    end
  end

  describe '.entities_manager' do

    before(:each) do
      allow(SimpleTokenAuthentication::EntitiesManager).to receive(:new)
        .and_return('a EntitiesManager instance')
    end

    context 'when called for the first time' do

      it 'creates a new EntitiesManager instance', private: true do
        expect(SimpleTokenAuthentication::EntitiesManager).to receive(:new)
        expect(subject.send(:entities_manager)).to eq 'a EntitiesManager instance'
      end
    end

    context 'when a EntitiesManager instance was already created' do

      before(:each) do
        subject.send(:entities_manager)
        # let's make any new EntitiesManager distinct from the first
        allow(SimpleTokenAuthentication::EntitiesManager).to receive(:new)
        .and_return('another EntitiesManager instance')
      end

      it 'returns that instance', private: true do
        expect(subject.send(:entities_manager)).to eq 'a EntitiesManager instance'
      end

      it 'does not create a new EntitiesManager instance', private: true do
        expect(SimpleTokenAuthentication::EntitiesManager).not_to receive(:new)
        expect(subject.send(:entities_manager)).not_to eq 'another EntitiesManager instance'
      end
    end
  end

  describe '.fallback_handler' do

    context 'when the Devise fallback is enabled', fallback_option: true do

      before(:each) do
        @options = { fallback: :devise }
      end

      it 'returns a DeviseFallbackHandler instance', private: true do
        expect(subject.send(:fallback_handler, @options)).to be_kind_of SimpleTokenAuthentication::DeviseFallbackHandler
      end
    end

    context 'when the Exception fallback is enabled', fallback_option: true do

      before(:each) do
        @options = { fallback: :exception }
      end

      it 'returns a ExceptionFallbackHandler instance', private: true do
        expect(subject.send(:fallback_handler, @options)).to be_kind_of SimpleTokenAuthentication::ExceptionFallbackHandler
      end
    end
  end

  describe '#find_record_from_identifier', private: true do

    before(:each) do
      @entity = double()
      # default identifer is :email
      allow(@entity).to receive(:identifier).and_return(:email)
    end

    context 'when the Devise config. does not defines the identifier as a case-insentitive key' do

      before(:each) do
        allow(Devise).to receive_message_chain(:case_insensitive_keys, :include?)
        .with(:email).and_return(false)
      end

      context 'when a downcased identifier was provided' do

        before(:each) do
          allow(@entity).to receive(:get_identifier_from_params_or_headers)
          .and_return('alice@example.com')
        end

        it 'returns the proper record if any' do
          # let's say there is a record
          record = double()
          allow(@entity).to receive_message_chain(:model, :find_for_authentication)
          .with(email: 'alice@example.com')
          .and_return(record)

          expect(subject.new.send(:find_record_from_identifier, @entity)).to eq record
        end
      end

      context 'when a upcased identifier was provided' do

        before(:each) do
          allow(@entity).to receive(:get_identifier_from_params_or_headers)
          .and_return('AliCe@ExampLe.Com')
        end

        it 'does not return any record' do
          # let's say there is a record...
          record = double()
          # ...whose identifier is downcased...
          allow(@entity).to receive_message_chain(:model, :find_for_authentication)
          .with(email: 'alice@example.com')
          .and_return(record)
          # ...not upcased
          allow(@entity).to receive_message_chain(:model, :find_for_authentication)
          .with(email: 'AliCe@ExampLe.Com')
          .and_return(nil)

          expect(subject.new.send(:find_record_from_identifier, @entity)).to be_nil
        end
      end
    end

    context 'when the Devise config. defines the identifier as a case-insentitive key' do

      before(:each) do
        allow(Devise).to receive_message_chain(:case_insensitive_keys, :include?)
        .with(:email).and_return(true)
      end

      context 'and a downcased identifier was provided' do

        before(:each) do
          allow(@entity).to receive(:get_identifier_from_params_or_headers)
          .and_return('alice@example.com')
        end

        it 'returns the proper record if any' do
          # let's say there is a record
          record = double()
          allow(@entity).to receive_message_chain(:model, :find_for_authentication)
          .with(email: 'alice@example.com')
          .and_return(record)

          expect(subject.new.send(:find_record_from_identifier, @entity)).to eq record
        end
      end

      context 'and a upcased identifier was provided' do

        before(:each) do
          allow(@entity).to receive(:get_identifier_from_params_or_headers)
          .and_return('AliCe@ExampLe.Com')
        end

        it 'returns the proper record if any' do
          # let's say there is a record...
          record = double()
          # ...whose identifier is downcased...
          allow(@entity).to receive_message_chain(:model, :find_for_authentication)
          allow(@entity).to receive_message_chain(:model, :find_for_authentication)
          .with(email: 'alice@example.com')
          .and_return(record)
          # ...not upcased
          allow(@entity).to receive_message_chain(:model, :find_for_authentication).with(email: 'AliCe@ExampLe.Com')
          .and_return(nil)

          expect(subject.new.send(:find_record_from_identifier, @entity)).to eq record
        end
      end
    end

    context 'when a custom identifier was defined', identifiers_option: true do

      before(:each) do
        allow(@entity).to receive(:identifier).and_return(:phone_number)
      end

      context 'when the Devise config. does not defines the identifier as a case-insentitive key' do

        before(:each) do
          allow(Devise).to receive_message_chain(:case_insensitive_keys, :include?)
          .with(:phone_number).and_return(false)
        end

        context 'when a downcased identifier was provided' do

          before(:each) do
            allow(@entity).to receive(:get_identifier_from_params_or_headers)
            .and_return('alice@example.com')
          end

          it 'returns the proper record if any' do
            # let's say there is a record
            record = double()
            allow(@entity).to receive_message_chain(:model, :find_for_authentication)
            .with(phone_number: 'alice@example.com')
            .and_return(record)

            expect(subject.new.send(:find_record_from_identifier, @entity)).to eq record
          end
        end

        context 'when a upcased identifier was provided' do

          before(:each) do
            allow(@entity).to receive(:get_identifier_from_params_or_headers)
            .and_return('AliCe@ExampLe.Com')
          end

          it 'does not return any record' do
            # let's say there is a record...
            record = double()
            # ...whose identifier is downcased...
            allow(@entity).to receive_message_chain(:model, :find_for_authentication)
            .with(phone_number: 'alice@example.com')
            .and_return(record)
            # ...not upcased
            allow(@entity).to receive_message_chain(:model, :find_for_authentication)
            .with(phone_number: 'AliCe@ExampLe.Com')
            .and_return(nil)

            expect(subject.new.send(:find_record_from_identifier, @entity)).to be_nil
          end
        end
      end

      context 'when the Devise config. defines the identifier as a case-insentitive key' do

        before(:each) do
          allow(Devise).to receive_message_chain(:case_insensitive_keys, :include?)
          .with(:phone_number).and_return(true)
        end

        context 'and a downcased identifier was provided' do

          before(:each) do
            allow(@entity).to receive(:get_identifier_from_params_or_headers)
            .and_return('alice@example.com')
          end

          it 'returns the proper record if any' do
            # let's say there is a record
            record = double()
            allow(@entity).to receive_message_chain(:model, :find_for_authentication)
            .with(phone_number: 'alice@example.com')
            .and_return(record)

            expect(subject.new.send(:find_record_from_identifier, @entity)).to eq record
          end
        end

        context 'and a upcased identifier was provided' do

          before(:each) do
            allow(@entity).to receive(:get_identifier_from_params_or_headers)
            .and_return('AliCe@ExampLe.Com')
          end

          it 'returns the proper record if any' do
            # let's say there is a record...
            record = double()
            # ...whose identifier is downcased...
            allow(@entity).to receive_message_chain(:model, :find_for_authentication)
            allow(@entity).to receive_message_chain(:model, :find_for_authentication)
            .with(phone_number: 'alice@example.com')
            .and_return(record)
            # ...not upcased
            allow(@entity).to receive_message_chain(:model, :find_for_authentication)
            .with(phone_number: 'AliCe@ExampLe.Com')
            .and_return(nil)

            expect(subject.new.send(:find_record_from_identifier, @entity)).to eq record
          end
        end
      end
    end
  end

  describe 'and which supports the :before_filter hook', before_filter: true do

    before(:each) do
      allow(subject).to receive(:before_filter)
    end

    # User

    context 'and which handles token authentication for User' do

      before(:each) do
        double_user_model
      end

      it 'ensures its instances require user to authenticate from token or any Devise strategy before any action', public: true do
        expect(subject).to receive(:before_filter).with(:authenticate_user_from_token!, {})
        subject.handle_token_authentication_for User
      end

      context 'and disables the fallback to Devise authentication' do

        let(:options) do
          { fallback_to_devise: false }
        end

        it 'ensures its instances require user to authenticate from token before any action', public: true do
          expect(subject).to receive(:before_filter).with(:authenticate_user_from_token, {})
          subject.handle_token_authentication_for User, options
        end
      end

      describe 'instance' do

        before(:each) do
          double_user_model

          subject.class_eval do
            handle_token_authentication_for User
          end
        end

        it 'responds to :authenticate_user_from_token', protected: true do
          expect(subject.new).to respond_to :authenticate_user_from_token
        end

        it 'responds to :authenticate_user_from_token!', protected: true do
          expect(subject.new).to respond_to :authenticate_user_from_token!
        end

        it 'does not respond to :authenticate_super_admin_from_token', protected: true do
          expect(subject.new).not_to respond_to :authenticate_super_admin_from_token
        end

        it 'does not respond to :authenticate_super_admin_from_token!', protected: true do
          expect(subject.new).not_to respond_to :authenticate_super_admin_from_token!
        end
      end
    end

    # SuperAdmin

    context 'and which handles token authentication for SuperAdmin' do

      before(:each) do
        double_super_admin_model
      end

      it 'ensures its instances require super_admin to authenticate from token or any Devise strategy before any action', public: true do
        expect(subject).to receive(:before_filter).with(:authenticate_super_admin_from_token!, {})
        subject.handle_token_authentication_for SuperAdmin
      end

      context 'and disables the fallback to Devise authentication' do

        let(:options) do
          { fallback_to_devise: false }
        end

        it 'ensures its instances require super_admin to authenticate from token before any action', public: true do
          expect(subject).to receive(:before_filter).with(:authenticate_super_admin_from_token, {})
          subject.handle_token_authentication_for SuperAdmin, options
        end
      end

      describe 'instance' do

        before(:each) do
          double_super_admin_model

          subject.class_eval do
            handle_token_authentication_for SuperAdmin
          end
        end

        it 'responds to :authenticate_super_admin_from_token', protected: true do
          expect(subject.new).to respond_to :authenticate_super_admin_from_token
        end

        it 'responds to :authenticate_super_admin_from_token!', protected: true do
          expect(subject.new).to respond_to :authenticate_super_admin_from_token!
        end

        it 'does not respond to :authenticate_user_from_token', protected: true do
          expect(subject.new).not_to respond_to :authenticate_user_from_token
        end

        it 'does not respond to :authenticate_user_from_token!', protected: true do
          expect(subject.new).not_to respond_to :authenticate_user_from_token!
        end
      end

      context 'with the :admin alias', token_authenticatable_aliases_option: true do

        let(:options) do
          { 'as' => :admin }
        end

        it 'ensures its instances require admin to authenticate from token or any Devise strategy before any action', public: true do
          expect(subject).to receive(:before_filter).with(:authenticate_admin_from_token!, {})
          subject.handle_token_authentication_for SuperAdmin, options
        end

        context 'and disables the fallback to Devise authentication' do

          let(:options) do
            { as: 'admin', fallback_to_devise: false }
          end

          it 'ensures its instances require admin to authenticate from token before any action', public: true do
            expect(subject).to receive(:before_filter).with(:authenticate_admin_from_token, {})
            subject.handle_token_authentication_for SuperAdmin, options
          end
        end

        describe 'instance' do

          before(:each) do
            double_super_admin_model

            subject.class_eval do
              handle_token_authentication_for SuperAdmin, as: :admin
            end
          end

          it 'responds to :authenticate_admin_from_token', protected: true do
            expect(subject.new).to respond_to :authenticate_admin_from_token
          end

          it 'responds to :authenticate_admin_from_token!', protected: true do
            expect(subject.new).to respond_to :authenticate_admin_from_token!
          end

          it 'does not respond to :authenticate_super_admin_from_token', protected: true do
            expect(subject.new).not_to respond_to :authenticate_super_admin_from_token
          end

          it 'does not respond to :authenticate_super_admin_from_token!', protected: true do
            expect(subject.new).not_to respond_to :authenticate_super_admin_from_token!
          end

          it 'does not respond to :authenticate_user_from_token', protected: true do
            expect(subject.new).not_to respond_to :authenticate_user_from_token
          end

          it 'does not respond to :authenticate_user_from_token!', protected: true do
            expect(subject.new).not_to respond_to :authenticate_user_from_token!
          end
        end
      end
    end
  end

  describe 'and which supports the :before_action hook', before_action: true do

    before(:each) do
      allow(subject).to receive(:before_action)
    end

    # User

    context 'and which handles token authentication for User' do

      before(:each) do
        double_user_model
      end

      it 'ensures its instances require user to authenticate from token or any Devise strategy before any action', public: true do
        expect(subject).to receive(:before_action).with(:authenticate_user_from_token!, {})
        subject.handle_token_authentication_for User
      end

      context 'and disables the fallback to Devise authentication' do

        let(:options) do
          { fallback_to_devise: false }
        end

        it 'ensures its instances require user to authenticate from token before any action', public: true do
          expect(subject).to receive(:before_action).with(:authenticate_user_from_token, {})
          subject.handle_token_authentication_for User, options
        end
      end

      describe 'instance' do

        before(:each) do
          double_user_model

          subject.class_eval do
            handle_token_authentication_for User
          end
        end

        it 'responds to :authenticate_user_from_token', protected: true do
          expect(subject.new).to respond_to :authenticate_user_from_token
        end

        it 'responds to :authenticate_user_from_token!', protected: true do
          expect(subject.new).to respond_to :authenticate_user_from_token!
        end

        it 'does not respond to :authenticate_super_admin_from_token', protected: true do
          expect(subject.new).not_to respond_to :authenticate_super_admin_from_token
        end

        it 'does not respond to :authenticate_super_admin_from_token!', protected: true do
          expect(subject.new).not_to respond_to :authenticate_super_admin_from_token!
        end
      end
    end

    # SuperAdmin

    context 'and which handles token authentication for SuperAdmin' do

      before(:each) do
        double_super_admin_model
      end

      it 'ensures its instances require super_admin to authenticate from token or any Devise strategy before any action', public: true do
        expect(subject).to receive(:before_action).with(:authenticate_super_admin_from_token!, {})
        subject.handle_token_authentication_for SuperAdmin
      end

      context 'and disables the fallback to Devise authentication' do

        let(:options) do
          { fallback_to_devise: false }
        end

        it 'ensures its instances require super_admin to authenticate from token before any action', public: true do
          expect(subject).to receive(:before_action).with(:authenticate_super_admin_from_token, {})
          subject.handle_token_authentication_for SuperAdmin, options
        end
      end

      describe 'instance' do

        before(:each) do
          double_super_admin_model

          subject.class_eval do
            handle_token_authentication_for SuperAdmin
          end
        end

        it 'responds to :authenticate_super_admin_from_token', protected: true do
          expect(subject.new).to respond_to :authenticate_super_admin_from_token
        end

        it 'responds to :authenticate_super_admin_from_token!', protected: true do
          expect(subject.new).to respond_to :authenticate_super_admin_from_token!
        end

        it 'does not respond to :authenticate_user_from_token', protected: true do
          expect(subject.new).not_to respond_to :authenticate_user_from_token
        end

        it 'does not respond to :authenticate_user_from_token!', protected: true do
          expect(subject.new).not_to respond_to :authenticate_user_from_token!
        end
      end

      context 'with the :admin alias', token_authenticatable_aliases_option: true do

        let(:options) do
          { 'as' => :admin }
        end

        it 'ensures its instances require admin to authenticate from token or any Devise strategy before any action', public: true do
          expect(subject).to receive(:before_action).with(:authenticate_admin_from_token!, {})
          subject.handle_token_authentication_for SuperAdmin, options
        end

        context 'and disables the fallback to Devise authentication' do

          let(:options) do
            { as: 'admin', fallback_to_devise: false }
          end

          it 'ensures its instances require admin to authenticate from token before any action', public: true do
            expect(subject).to receive(:before_action).with(:authenticate_admin_from_token, {})
            subject.handle_token_authentication_for SuperAdmin, options
          end
        end

        describe 'instance' do

          before(:each) do
            double_super_admin_model

            subject.class_eval do
              handle_token_authentication_for SuperAdmin, as: :admin
            end
          end

          it 'responds to :authenticate_admin_from_token', protected: true do
            expect(subject.new).to respond_to :authenticate_admin_from_token
          end

          it 'responds to :authenticate_admin_from_token!', protected: true do
            expect(subject.new).to respond_to :authenticate_admin_from_token!
          end

          it 'does not respond to :authenticate_super_admin_from_token', protected: true do
            expect(subject.new).not_to respond_to :authenticate_super_admin_from_token
          end

          it 'does not respond to :authenticate_super_admin_from_token!', protected: true do
            expect(subject.new).not_to respond_to :authenticate_super_admin_from_token!
          end

          it 'does not respond to :authenticate_user_from_token', protected: true do
            expect(subject.new).not_to respond_to :authenticate_user_from_token
          end

          it 'does not respond to :authenticate_user_from_token!', protected: true do
            expect(subject.new).not_to respond_to :authenticate_user_from_token!
          end
        end
      end
    end
  end

  describe '#authenticate_entity_from_token!' do

    let(:token_authentication_handler) { described_class.new }

    before(:each) do
      allow(token_authentication_handler).to receive(:find_record_from_identifier)
      allow(token_authentication_handler).to receive(:perform_sign_in!)
      allow(token_authentication_handler).to receive(:token_correct?).and_return(false)
    end

    context 'when authentication is not succesful and the handler implements the :after_successful_token_authentication hook', private: true do
      before(:each) do
        allow(token_authentication_handler).to receive(:token_correct?).and_return(false)
        allow(token_authentication_handler).to receive(:after_successful_token_authentication)
      end

      it 'does not trigger the :after_successful_token_authentication hook' do
        token_authentication_handler.send(:authenticate_entity_from_token!, double)
        expect(token_authentication_handler).not_to have_received(:after_successful_token_authentication)
      end
    end

    context 'when authentication is succesful' do
      before(:each) do
        allow(token_authentication_handler).to receive(:token_correct?).and_return(true)
      end

      context 'when the handler does not implement :after_successful_token_authentication', protected: true do
        it 'does not trigger the :after_successful_token_authentication hook' do
          expect(token_authentication_handler).not_to respond_to(:after_successful_token_authentication)
          expect { token_authentication_handler.send(:authenticate_entity_from_token!, double) }.not_to raise_error
        end
      end

      context 'when the handler implements :after_successful_token_authentication', protected: true do
        before(:each) do
          allow(token_authentication_handler).to receive(:after_successful_token_authentication)
        end

        it 'calls the :after_successful_token_authentication hook' do
          token_authentication_handler.send(:authenticate_entity_from_token!, double)
          expect(token_authentication_handler).to have_received(:after_successful_token_authentication).once
        end
      end
    end
  end
end
