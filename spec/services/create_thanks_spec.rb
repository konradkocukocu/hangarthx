# frozen_string_literal: true

require "rails_helper"

tomek_ryba = {
  user: {
    id: "AFN6FJUR3",
    name: "tomek.ryba",
    real_name: "Tomek Ryba",
    profile: {
      image_72: "http://test.image.tomek",
    },
  },
}

foo_bar = {
  user: {
    id: "AFN6FJUR4",
    name: "foo.bar",
    real_name: "Foo Bar",
    profile: {
      image_72: "http://test.image.foo",
    },
  },
}

joe_doe = {
  user: {
    id: "AFN6FJUR5",
    name: "joe.doe",
    real_name: "Joe Doe",
    profile: {
      image_72: "http://test.image.joe",
    },
  },
}

slack_users = {
  "@tomek.ryba" => tomek_ryba,
  "AFN6FJUR3" => tomek_ryba,
  "@foo.bar" => foo_bar,
  "AFN6FJUR4" => foo_bar,
  "@joe.doe" => joe_doe,
  "AFN6FJUR5" => joe_doe,
}

slack_groups = {
  usergroups: [
    {
      handle: "Test",
      users: %w[
        AFN6FJUR4
        AFN6FJUR5
      ],
    },
  ],
}

describe CreateThanks do
  let(:fake_slack) { Adapters::FakeSlack.new(slack_users, slack_groups) }
  let(:service) { CreateThanks.new(fake_slack) }
  let(:command_1_text) { "Thanks @joe.doe for food" }
  let(:command_2_text) { "Thanks for food" }
  let(:command_3_text) { "Thanks @Test for food" }
  let(:command_4_text) { "Thanks @fake for food" }
  let(:command_5_text) do
    "Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Aenean commodo" \
      "ligula eget dolor. Aenean massa. Cum sociis natoque penatibus et magnis dis" \
      "parturient montes, nascetur ridiculus mus. Donec quam felis, ultricies nec," \
      "pellentesque eu, pretium quis, sem. Nulla consequat massa quis enim. Donec.!!!!!"
  end
  let(:command_6_text) { "Thanks <!subteam^SEQ8LFHR7|@Test> for food" }
  let(:thanks_request_1) { thanks_request_params("tomek.ryba", command_1_text) }
  let(:thanks_request_2) { thanks_request_params("tomek.ryba", command_2_text) }
  let(:thanks_request_3) { thanks_request_params("tomek.ryba", command_3_text) }
  let(:thanks_request_4) { thanks_request_params("tomek.ryba", command_4_text) }
  let(:thanks_request_5) { thanks_request_params("tomek.ryba", command_5_text) }
  let(:thanks_request_6) { thanks_request_params("tomek.ryba", command_6_text) }

  before do
    @time = Time.zone.now
    Timecop.freeze(@time)
  end

  it "should create thanks" do
    service.perform(thanks_request_1)
    thanks = Thanks.order(created_at: :desc).all

    expect(thanks.length).to eq 1
    expect(thanks[0].receivers.length).to eq 1
    expect(thanks[0].giver).to eq expected_user(slack_users["@tomek.ryba"][:user])
    expect(thanks[0].receivers[0]).to eq expected_user(slack_users["@joe.doe"][:user])
    expect(thanks[0].love_count).to eq 0
    expect(thanks[0].confetti_count).to eq 0
    expect(thanks[0].clap_count).to eq 0
    expect(thanks[0].wow_count).to eq 0
    expect(thanks[0].popularity).to eq 0
    expect(thanks[0].text).to eq command_1_text
  end

  it "should save users locally once" do
    service.perform(thanks_request_1)
    users = SlackUser.order(created_at: :desc).all
    user_0 = expected_user(slack_users["@tomek.ryba"][:user])
    user_1 = expected_user(slack_users["@joe.doe"][:user])

    expect(users.length).to eq 2
    expect(users[0].id).to eq user_0["id"]
    expect(users[0].name).to eq user_0["name"]
    expect(users[0].real_name).to eq user_0["real_name"]
    expect(users[0].avatar_url).to eq user_0["avatar_url"]
    expect(users[0].thanks_sent).to eq 1
    expect(users[0].thanks_recived).to eq 0

    expect(users[1].id).to eq user_1["id"]
    expect(users[1].name).to eq user_1["name"]
    expect(users[1].real_name).to eq user_1["real_name"]
    expect(users[1].avatar_url).to eq user_1["avatar_url"]
    expect(users[1].thanks_sent).to eq 0
    expect(users[1].thanks_recived).to eq 1

    service.perform(thanks_request_1)
    users = SlackUser.order(created_at: :desc).all
    expect(users.length).to eq 2
  end

  it "should send thanksy on slack channel" do
    service.perform(thanks_request_1)
    response_url = thanks_request_1[:response_url]
    thanks = Thanks.order(created_at: :desc).last
    expected_response = SlackResponse.new.in_channel("tomek.ryba", thanks)

    expect(fake_slack.responses[response_url]).to eq expected_response
  end

  it "should create thanks if receiver is not set" do
    service.perform(thanks_request_2)
    thanks = Thanks.order(created_at: :desc).all

    expect(thanks.length).to eq 1
    expect(thanks[0].receivers.length).to eq 0
    expect(thanks[0].giver).to eq expected_user(slack_users["@tomek.ryba"][:user])
    expect(thanks[0].receivers).to eq []
    expect(thanks[0].love_count).to eq 0
    expect(thanks[0].confetti_count).to eq 0
    expect(thanks[0].clap_count).to eq 0
    expect(thanks[0].wow_count).to eq 0
    expect(thanks[0].popularity).to eq 0
    expect(thanks[0].text).to eq command_2_text
  end

  it "should create thanks if receiver is not set" do
    service.perform(thanks_request_2)
    thanks = Thanks.order(created_at: :desc).all

    expect(thanks.length).to eq 1
    expect(thanks[0].receivers.length).to eq 0
    expect(thanks[0].giver).to eq expected_user(slack_users["@tomek.ryba"][:user])
    expect(thanks[0].receivers).to eq []
    expect(thanks[0].love_count).to eq 0
    expect(thanks[0].confetti_count).to eq 0
    expect(thanks[0].clap_count).to eq 0
    expect(thanks[0].wow_count).to eq 0
    expect(thanks[0].popularity).to eq 0
    expect(thanks[0].text).to eq command_2_text
  end

  it "should create thanks for group of users" do
    service.perform(thanks_request_3)
    thanks = Thanks.order(created_at: :desc).all

    expect(thanks.length).to eq 1
    expect(thanks[0].receivers.length).to eq 2
    expect(thanks[0].giver).to eq expected_user(slack_users["@tomek.ryba"][:user])
    expect(thanks[0].receivers[0]).to eq expected_user(slack_users["@foo.bar"][:user])
    expect(thanks[0].receivers[1]).to eq expected_user(slack_users["@joe.doe"][:user])
    expect(thanks[0].love_count).to eq 0
    expect(thanks[0].confetti_count).to eq 0
    expect(thanks[0].clap_count).to eq 0
    expect(thanks[0].wow_count).to eq 0
    expect(thanks[0].popularity).to eq 0
    expect(thanks[0].text).to eq command_3_text
  end

  it "should create thanks for group of users" do
    service.perform(thanks_request_3)
    thanks = Thanks.order(created_at: :desc).all

    expect(thanks.length).to eq 1
    expect(thanks[0].receivers.length).to eq 2
    expect(thanks[0].giver).to eq expected_user(slack_users["@tomek.ryba"][:user])
    expect(thanks[0].receivers[0]).to eq expected_user(slack_users["@foo.bar"][:user])
    expect(thanks[0].receivers[1]).to eq expected_user(slack_users["@joe.doe"][:user])
    expect(thanks[0].love_count).to eq 0
    expect(thanks[0].confetti_count).to eq 0
    expect(thanks[0].clap_count).to eq 0
    expect(thanks[0].wow_count).to eq 0
    expect(thanks[0].popularity).to eq 0
    expect(thanks[0].text).to eq command_3_text
  end

  it "should fail if receiver doesn't exist" do
    service.perform(thanks_request_4)
    response_url = thanks_request_4[:response_url]
    thanks = Thanks.order(created_at: :desc).all
    expected_response = { text: "User or group fake doesn't exist" }

    expect(fake_slack.responses[response_url]).to eq expected_response
    expect(thanks.length).to eq 0
  end

  it "should fail if thanksy text is longer than 300 characters" do
    service.perform(thanks_request_5)
    response_url = thanks_request_5[:response_url]
    thanks = Thanks.order(created_at: :desc).all
    expected_response = { text: "Given text is longer than 300 characters" }

    expect(fake_slack.responses[response_url]).to eq expected_response
    expect(thanks.length).to eq 0
  end

  it "should remove group variables" do
    service.perform(thanks_request_6)
    thanks = Thanks.order(created_at: :desc).all

    expect(thanks.length).to eq 1
    expect(thanks[0].text).to eq "Thanks @Test for food"
  end
end

private

def expected_user(user_data)
  {
    "id" => user_data[:id],
    "name" => user_data[:name],
    "real_name" => user_data[:real_name],
    "avatar_url" => user_data[:profile][:image_72],
    "created_at" => @time.strftime("%FT%T.%LZ"),
    "updated_at" => @time.strftime("%FT%T.%LZ"),
  }
end
