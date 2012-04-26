# TODO: remove hacky workaround for duplicated tweets in conversations
module TweetComparator

  def hash
    self.text.hash
  end

  def eql?(other)
    self.text == other.text
  end

end
