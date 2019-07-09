{"url":"https://api.github.com/repos/nitlang/nit/pulls/comments/21010363","pull_request_review_id":null,"id":21010363,"node_id":"MDI0OlB1bGxSZXF1ZXN0UmV2aWV3Q29tbWVudDIxMDEwMzYz","diff_hunk":"@@ -981,11 +983,11 @@ redef class AAttrPropdef\n \n \t\t\t\tif mtype == null then return\n \t\t\tend\n-\t\telse if ntype != null then\n+\t\telse if ntype != null and inherited_type == mtype then\n \t\t\tif nexpr isa ANewExpr then\n \t\t\t\tvar xmtype = modelbuilder.resolve_mtype(mmodule, mclassdef, nexpr.n_type)\n \t\t\t\tif xmtype == mtype then\n-\t\t\t\t\tmodelbuilder.advice(ntype, \"useless-type\", \"Warning: useless type definition\")\n+\t\t\t\t\tmodelbuilder.advice(ntype, \"useless-type\", \"Warning: useless type definition {inherited_type or else \"?\"}\")","path":"src/modelize/modelize_property.nit","position":null,"original_position":26,"commit_id":"ce5e187a87ed5c41144ea5637188a0677d840fdc","original_commit_id":"5f0ab1c7f3c560a67867d5eb08f5c3082f251c20","user":{"login":"jcbrinfo","id":6044484,"node_id":"MDQ6VXNlcjYwNDQ0ODQ=","avatar_url":"https://avatars0.githubusercontent.com/u/6044484?v=4","gravatar_id":"","url":"https://api.github.com/users/jcbrinfo","html_url":"https://github.com/jcbrinfo","followers_url":"https://api.github.com/users/jcbrinfo/followers","following_url":"https://api.github.com/users/jcbrinfo/following{/other_user}","gists_url":"https://api.github.com/users/jcbrinfo/gists{/gist_id}","starred_url":"https://api.github.com/users/jcbrinfo/starred{/owner}{/repo}","subscriptions_url":"https://api.github.com/users/jcbrinfo/subscriptions","organizations_url":"https://api.github.com/users/jcbrinfo/orgs","repos_url":"https://api.github.com/users/jcbrinfo/repos","events_url":"https://api.github.com/users/jcbrinfo/events{/privacy}","received_events_url":"https://api.github.com/users/jcbrinfo/received_events","type":"User","site_admin":false},"body":"Warning: `inherited_type` is always non null here.\n","created_at":"2014-11-27T20:39:29Z","updated_at":"2014-11-28T01:05:12Z","html_url":"https://github.com/nitlang/nit/pull/945#discussion_r21010363","pull_request_url":"https://api.github.com/repos/nitlang/nit/pulls/945","author_association":"CONTRIBUTOR","_links":{"self":{"href":"https://api.github.com/repos/nitlang/nit/pulls/comments/21010363"},"html":{"href":"https://github.com/nitlang/nit/pull/945#discussion_r21010363"},"pull_request":{"href":"https://api.github.com/repos/nitlang/nit/pulls/945"}}}