require 'rails_helper'

RSpec.describe ReceiveIssueCommentEvent do
  let(:reviewer) { "aergonaut" }

  let!(:pr) { FactoryGirl.create :pull_request, status: "pending_review", pending_reviews: [reviewer] }

  let(:payload) do
    from_fixture = JSON.load(File.open(Rails.root.join("spec", "fixtures", "issue_comment.json")))
    from_fixture["issue"]["number"] = pr.number
    from_fixture["sender"]["login"] = reviewer
    from_fixture["comment"]["body"] = comment
    from_fixture
  end

  let(:job) { ReceiveIssueCommentEvent.new }

  let(:comment) { "lgtm" }

  describe "#perform" do
    before do
      stub_request(:post, %r(https?://api.github.com/repos/\w+/\w+/statuses/[0-9abcdef]{40}))
      stub_request(:get, %r(https?://api.github.com/repos/\w+/\w+/pulls/\d+)).to_return(
        body: File.open(Rails.root.join("spec", "fixtures", "pr.json")),
        status: 200,
        headers: { "Content-Type" => "application/json" }
      )
      job.perform(payload)
    end

    context "when the commenter is a reviewer" do
      context "and they approve" do
        it "moves them into the completed_reviews list" do
          pr.reload
          expect(pr.pending_reviews).to_not include(reviewer)
          expect(pr.completed_reviews).to include(reviewer)
        end

        context "and they are the last approver" do
          it "updates the status on GitHub" do
            expect(WebMock).to have_requested(:post, %r(https?://api.github.com/repos/\w+/\w+/statuses/[0-9abcdef]{40}))
          end

          it "marks the PR as approved" do
            expect(pr.reload.status).to eq("approved")
          end
        end
      end
    end
  end
end