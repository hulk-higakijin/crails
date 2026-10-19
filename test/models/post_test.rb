require "test_helper"

class PostTest < ActiveSupport::TestCase
  test "requires title" do
    post = Post.new(body: "No title")
    assert_not post.valid?
  end

  test "saves with title and body" do
    post = Post.new(title: "Hello", body: "First post")
    assert post.valid?
  end
end
