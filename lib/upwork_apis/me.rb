module UpworkApis
	class Me < Base
		private

		def params
			{
			 'query' => "query {
				 user {
				   id
				   nid
				   rid
				   email
				   name
				   photoUrl
				 }
				 organization {
				   id
				 }
			   }"
			}
		end
	end
end
