require "test_helper"

class PostsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @post = Post.create!(title: "Hello", body: "First post")
  end

  test "gets index" do
    get posts_url
    assert_response :success
  end

  test "gets show" do
    get post_url(@post)
    assert_response :success
  end
end
