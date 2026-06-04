# typed: true
# frozen_string_literal: true

require "download_strategy"
require "utils/svn"

RSpec.describe SubversionDownloadStrategy do
  subject(:strategy) { klass.new(url, name, version, **specs) }

  let(:klass) { SubversionDownloadStrategy }
  let(:name) { "foo" }
  let(:url) { "https://example.com/foo.tar.gz" }
  let(:version) { "1.2.3" }
  let(:specs) { {} }

  describe "#fetch" do
    before do
      allow(strategy).to receive(:repo_url).and_return("#{url}/old")
    end

    context "with :trust_cert set" do
      let(:specs) { { trust_cert: true } }

      before do
        allow(Utils::Svn).to receive(:version).and_return("1.14.5")
      end

      it "adds the appropriate svn args" do
        expect(strategy).to receive(:system_command!)
          .with("svn", hash_including(args: array_including("--trust-server-cert", "--non-interactive")))
          .and_return(instance_double(SystemCommand::Result))

        strategy.fetch
      end
    end

    context "with :revision set" do
      let(:specs) { { revision: "10" } }

      it "adds svn arguments for :revision" do
        expect(strategy).to receive(:system_command!)
          .with("svn", hash_including(args: array_including_cons("-r", "10")))
          .and_return(instance_double(SystemCommand::Result))

        strategy.fetch
      end
    end
  end
end
