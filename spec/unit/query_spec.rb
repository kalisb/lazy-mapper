require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))

class Article < LazyMapper::Model
  property :id,         Integer, serial: true
  property :blog_id,    Integer
  property :created_at, DateTime
  property :author,     String
  property :title,      String
end

GOOD_OPTIONS = [
  [ :reload,   false     ],
  [ :reload,   true      ],
  [ :offset,   0         ],
  [ :offset,   1         ],
  [ :limit,    1         ],
  [ :limit,    2         ],
  [ :order,    [ LazyMapper::Query::Direction.new(Article.properties[:created_at], :desc) ] ],
  [ :fields,   Article.properties(:default).defaults.to_a ]
]

describe LazyMapper::Query do
  describe 'should set the attribute' do
    it '#model with model' do
      query = LazyMapper::Query.new(repository(:mock), Article)
      expect(query.model).to eq Article
    end

   GOOD_OPTIONS.each do |(attribute, value)|
     it "##{attribute} with options[:#{attribute}] if it is #{value.inspect}" do
       query = LazyMapper::Query.new(repository(:mock), Article, attribute => value)
       expect(query.send(attribute)).to eq value
     end
   end
  end
end
