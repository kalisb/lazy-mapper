require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))

describe LazyMapper::Associations::Relationship do
  it "should describe an association" do
    belongs_to = LazyMapper::Associations::Relationship.new(
      :manufacturer,
      :mock,
      'Vehicle',
      'Manufacturer',
      { child_key: [ :manufacturer_id ] }
    )

    expect(belongs_to).to respond_to(:name)
    expect(belongs_to).to respond_to(:repository_name)
    expect(belongs_to).to respond_to(:child_key)
    expect(belongs_to).to respond_to(:parent_key)
  end
end
