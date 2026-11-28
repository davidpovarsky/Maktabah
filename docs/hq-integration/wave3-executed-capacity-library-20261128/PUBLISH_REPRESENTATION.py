import os,pathlib,json,hashlib,stat,subprocess,base64,datetime,time,re,zipfile,io
os.umask(0o077)
CFG=json.loads("{\"groups\":[{\"source\":\"/home/ubuntu/otzaria-wave3-closed-workspace-nine-scope-proposal-20261128\",\"prefix\":\"nine-source\",\"files\":[{\"path\":\"DESTINATION_ABSENCE_READ.json\",\"bytes\":426,\"sha256\":\"bcd4ddb7a28531c5e69e7654aa19a9a1ce34d07d29566a3b1d31a9fa000ab0cb\"},{\"path\":\"GIT_DEPENDENCY_OBSERVATION.json\",\"bytes\":42597,\"sha256\":\"40e0a69f2569f0a9a4543237c6d9d325ea853f0d186eb38b5a877c67f50c333c\"},{\"path\":\"NINE_SCOPE_DELTA.json\",\"bytes\":7336,\"sha256\":\"22057c6a3ab91ddc0047f8b52201db4a460a47da9316ff8215170d55644e1653\"},{\"path\":\"NINE_SCOPE_PLAN.ndiff\",\"bytes\":136934,\"sha256\":\"5c1e43e9b661f8d9ee2fa3193dd14bf335ddd2eb64dee95a7a4dfc993d7f6e66\"},{\"path\":\"NINE_SCOPE_PLAN.patch\",\"bytes\":68734,\"sha256\":\"0660f09b62b8e65725c7b5a0ad44d856b00c8e451b6c4f55136042b275f66e42\"},{\"path\":\"NINE_SCOPE_SOURCE.ndiff\",\"bytes\":66575,\"sha256\":\"7c1beb16df7785dbbd63f3e39393a6b6fbb31ff8a77cfa569854cc83544a4c76\"},{\"path\":\"NINE_SCOPE_SOURCE.patch\",\"bytes\":6582,\"sha256\":\"f9a4aee216eaba569c0e3d5f11a386b533cc1b80af5d590aa46c4c93cf8cca3f\"},{\"path\":\"PLAN.json\",\"bytes\":34004,\"sha256\":\"5fd869b434cf887eadc4e56cc05bc7959f47f8b0998f0f760cc682054746b3d7\"},{\"path\":\"PLAN_FORMAT_PRESERVATION.json\",\"bytes\":1955,\"sha256\":\"6a5df9f664bd0f54b2a8e0c014f00e50bf4dd02ed1847932149bce0bda5f0730\"},{\"path\":\"PRIOR_CONTROLLER_FA0EA.py\",\"bytes\":15955,\"sha256\":\"fa0ea1728f77e0481c7098629d64c80efd75638b97a948398ef28f1a57f54d57\"},{\"path\":\"PRIOR_FINAL_DELTA_REVIEW.json\",\"bytes\":610,\"sha256\":\"782aae98413732f0df683e0694bdf8f08a4ebaf9b603e2b16dcc0630769486e1\"},{\"path\":\"PRIOR_PEER_REVIEW.json\",\"bytes\":1768,\"sha256\":\"26f04ffee6f7876321db96965149a1f351e2d957743d69464391f7a374c051ad\"},{\"path\":\"PROPOSAL_INPUTS.json\",\"bytes\":48350,\"sha256\":\"777e2f3608bcb6589741bac56ce83e33a8aad27cbb6ad79b381e046cb2785f30\"},{\"path\":\"README.md\",\"bytes\":5465,\"sha256\":\"d63209e9da555aa9153a7dbb5fd4f5d4768e795e52800dd7e21487253fd4c240\"},{\"path\":\"RELOCATE_CLOSED_WORKSPACES.py\",\"bytes\":61483,\"sha256\":\"a729ef49eb039a7f66b6a0447044d2f198310018e60652e37087b03ed1d79b76\"},{\"path\":\"SEAL_AUTHORING_DISPATCH_FAILURE.json\",\"bytes\":442,\"sha256\":\"16f3c08c52d12455d6631c4a47a15c8206ff54b8376ffbd1bb512f2776ab9e8d\"},{\"path\":\"SOURCE_ONLY_REVIEW.json\",\"bytes\":1272,\"sha256\":\"07299f0cddfbcf56c3bf3a4f0d895fd2dc2940d059e34cba4a41b8b0553852a8\"},{\"path\":\"TEN_SCOPE_ACTUAL_PREPARE_REFUSAL.json\",\"bytes\":909,\"sha256\":\"12313222c71ef12e2595b549481fb4db2d43b5a2a307c73ad04f60517eaa414e\"},{\"path\":\"prior/TEN_SCOPE_CONTROLLER.py\",\"bytes\":61275,\"sha256\":\"26961364780afc5da77a4b30d03dad7561960d8aeb4f738d9edce3cf7125c587\"},{\"path\":\"prior/TEN_SCOPE_HANDOFF.json\",\"bytes\":3126,\"sha256\":\"4f272458276dff94207d2bda72011e380bedfd11fc95c9bd6fcccdd892c221b4\"},{\"path\":\"prior/TEN_SCOPE_PLAN.json\",\"bytes\":34672,\"sha256\":\"2db5c1be24a2a9e8431388e98c948f0858f331dea6f74d30e932489818d379db\"},{\"path\":\"prior/TEN_SCOPE_SOURCE_MANIFEST.json\",\"bytes\":11645,\"sha256\":\"78f7315c32789af71d150a16aed7cb56939365dff4a8a78547962e0ae0979615\"},{\"path\":\"prior/TEN_SCOPE_SOURCE_RAW.zip\",\"bytes\":204394,\"sha256\":\"b3dd37c32dc0997424b02ca600119f29cba1ef127d45d6fd9c123fcbc6b22994\"},{\"path\":\"review/before-original-canonical-plan-format/NINE_SCOPE_DELTA.json\",\"bytes\":7336,\"sha256\":\"7c9bf5cc838cbf26e709d8c587862c6470e2b874202c4aefcffcb5aaa6a7c72e\"},{\"path\":\"review/before-original-canonical-plan-format/NINE_SCOPE_PLAN.ndiff\",\"bytes\":82124,\"sha256\":\"3202afb940432a694ab3925bab517d3cf6396d337ba75e8b4bed0d786758a365\"},{\"path\":\"review/before-original-canonical-plan-format/NINE_SCOPE_PLAN.patch\",\"bytes\":81173,\"sha256\":\"cef1a4e4e52cad64bec06c0df7b9a2c26a4fa38783c75f34389b758ae5894536\"},{\"path\":\"review/before-original-canonical-plan-format/NINE_SCOPE_SOURCE.ndiff\",\"bytes\":66575,\"sha256\":\"5db3f7fe94f86297bf0249c484d772e6ea46e99fbf5feb13cf56a3ec6bfa4b70\"},{\"path\":\"review/before-original-canonical-plan-format/NINE_SCOPE_SOURCE.patch\",\"bytes\":6582,\"sha256\":\"0e680cf704e6e3eb20ac930efe164ff81a16f4001884d4bc27288dbe5d1ab246\"},{\"path\":\"review/before-original-canonical-plan-format/PLAN.json\",\"bytes\":45428,\"sha256\":\"c967db0185109fe563023eb960546d50076f6b60b0a2cfa2f53f5e2c3dbf72d5\"},{\"path\":\"review/before-original-canonical-plan-format/RELOCATE_CLOSED_WORKSPACES.py\",\"bytes\":61483,\"sha256\":\"1f1d3050b8df02bba621bef32261759b42e1bf8499365283c6cd90038e3e2954\"},{\"path\":\"SOURCE_MANIFEST.json\",\"bytes\":8507,\"sha256\":\"7877d5e2475e072d1ff705d2de5ff951c757ed21f22288bb1f67c86591b4033f\"},{\"path\":\"HANDOFF.json\",\"bytes\":2048,\"sha256\":\"5ce44478c72982b775cddf931743bd92d178147b993d380f528c9d6be097ef67\"},{\"path\":\"SOURCE_PROPOSAL_RAW.zip\",\"bytes\":408592,\"sha256\":\"2edeefd3e9b914b129d5cceace84c99212b585621913778e3815b1c42a8bf0ab\"}]},{\"source\":\"/home/ubuntu/otzaria-wave3-preserved-untracked-leaf-git-endpoint2-continuation-20261128\",\"prefix\":\"leaf-source\",\"files\":[{\"path\":\"ACTUAL_SECOND_FAILURE_JOB.json\",\"bytes\":1500,\"sha256\":\"8954489d1adf9182865467be3a5c9116745e7a34a628a3610410e54d9236ddaa\"},{\"path\":\"AUTHOR_SOURCE.py\",\"bytes\":87143,\"sha256\":\"33e30f347b3df2da658f1ede681ccded98deb25525957cb2a991b99acdad4590\"},{\"path\":\"FIRST_FAILED_01-git-repository.PROCESS.json\",\"bytes\":320,\"sha256\":\"f54434c31c675ee0e8213758a0bd64a00e74ea58934dac2d091236b1e8205abd\"},{\"path\":\"FIRST_FAILED_01-git-repository.TERMINAL.json\",\"bytes\":449,\"sha256\":\"1ec9f1db5046c664261d0b5c5a23bc340227dd0d912b9fdc0798372583ec12b7\"},{\"path\":\"FIRST_FAILED_01-git-repository.stderr\",\"bytes\":25,\"sha256\":\"d2c8985c89b29a842ac4946d13bdbc297709f44f20bb968faf9682664b211db6\"},{\"path\":\"FIRST_FAILED_01-git-repository.stdout\",\"bytes\":106,\"sha256\":\"edbd0367cec893df36f67acb56c3aa23810be28850977c35e0fedaf64aad286b\"},{\"path\":\"FIRST_FAILED_SOURCE_SEAL_CURRENT.json\",\"bytes\":943,\"sha256\":\"b3fb30020b2bafffd741829e78974f1fa088e20c70d5291d8d35648463ab0e1e\"},{\"path\":\"FIRST_FAILED_TERMINAL_RESULT.json\",\"bytes\":405,\"sha256\":\"2c8128b0aa8649e635ef398228fa0e7da60488c58fbc8e7c0320c12a60cb3e27\"},{\"path\":\"HANDOFF.json\",\"bytes\":1689,\"sha256\":\"e64fd1a59052858d1d640c3c510546adf7df4c44e59dcf8a97f4b60991c36392\"},{\"path\":\"HELPER_CHANGE.patch\",\"bytes\":1381,\"sha256\":\"b21e77edba7ba653b0b38ea84348688b6ca2f57a201ade50f8ff76cc18bb942f\"},{\"path\":\"ORIGINAL_FAILURE_PINS.json\",\"bytes\":827,\"sha256\":\"661f98ba9445ce2486dd90884bbf1887702708169988775495d35b8f3eb50ff7\"},{\"path\":\"ORIGINAL_HELPER_CHANGE.patch\",\"bytes\":1668,\"sha256\":\"96c797cb2b8c8199933dad977095f29002deef57b2858c0eb485d574addd1232\"},{\"path\":\"ORIGINAL_HELPER_CHANGE_LEDGER.json\",\"bytes\":1113,\"sha256\":\"89a272f897d9ad5b0053af06cc750c7730b501fadcf48675f288766740ef41eb\"},{\"path\":\"ORIGINAL_SCOPE_PRESERVATION.json\",\"bytes\":17009,\"sha256\":\"2b3ce68a03c9a68298f978e69dcd44f00451e2de449af67294d5196b5e6ae80f\"},{\"path\":\"ORIGINAL_SOURCE_HANDOFF.json\",\"bytes\":1021,\"sha256\":\"a01a028d07af31e5c84c337cc03e1f67a2a5b723f5f9aad3436324d1f23d65fb\"},{\"path\":\"ORIGINAL_SOURCE_MANIFEST.json\",\"bytes\":2630,\"sha256\":\"20a79f38009c768ad3b6c3ad2ee4d90d150117d638f30956ce62d8f90371d5aa\"},{\"path\":\"ORIGINAL_SOURCE_PACKET_RAW.zip\",\"bytes\":61016,\"sha256\":\"876f8034c13da523e89a14ec568b78a7584f4a414488f53f748fd262a554c605\"},{\"path\":\"PRIOR_continue_retirement.py\",\"bytes\":6708,\"sha256\":\"0398870b2357896136f5fa06d397f6a15003c13f7f839ba8547ffb68a1dd3a97\"},{\"path\":\"PRIOR_leaf_common.py\",\"bytes\":47065,\"sha256\":\"a9bfb63bfd5538b51450051ddd8a0260d4396d856d6f4b9a64d255216b63afa7\"},{\"path\":\"PRIOR_leaf_common_endpoint.py\",\"bytes\":47162,\"sha256\":\"0fa4e870d58c390a8687731259cebfeb1ee2261903dbc6f3e046114f67a3aed6\"},{\"path\":\"PRIOR_retire_untracked_leaf.py\",\"bytes\":15254,\"sha256\":\"ec5ad989426b3cc2d6637092c7cdbbe70221a2a6653fa5c1ce76cc8afdae098f\"},{\"path\":\"README.txt\",\"bytes\":2433,\"sha256\":\"52c6459d12f7040e067adb1dd6a813551a3ef9b924645c60f6d68278fb9dcbaa\"},{\"path\":\"SECOND_FAILED_CONTINUATION_SOURCE_BINDING.json\",\"bytes\":919,\"sha256\":\"22a5dbd9ec30e6f015c3de12370fdbde1a0c53e41bd86a4d4be1c680fce017e4\"},{\"path\":\"SECOND_FAILED_SOURCE_SEAL_CURRENT.json\",\"bytes\":943,\"sha256\":\"b3fb30020b2bafffd741829e78974f1fa088e20c70d5291d8d35648463ab0e1e\"},{\"path\":\"SECOND_FAILED_TERMINAL_RESULT.json\",\"bytes\":403,\"sha256\":\"a00d5ca2b0542117ed144fdb05f91a5e5c87a0a30105a1c85c000b709012cfb7\"},{\"path\":\"SECOND_FAILURE_PINS.json\",\"bytes\":415,\"sha256\":\"428b049ed9fac6d23cc4cdba3298308e513c3ef51dc763ce1f0a10ae22aa94d5\"},{\"path\":\"SOURCE_CHANGE_LEDGER.json\",\"bytes\":4864,\"sha256\":\"27e4ca0a6ac70d277e7fca85e94f48356d78d9ca629d9459f3c3edd592b2cf06\"},{\"path\":\"SOURCE_MANIFEST.json\",\"bytes\":4935,\"sha256\":\"02c9c45f5c8daea6aa295640adc88cdc9feadc7955dceed77705beb528c78cb9\"},{\"path\":\"SOURCE_PACKET_RAW.zip\",\"bytes\":158102,\"sha256\":\"3f8b5bfe654469d2a07ce3981c7c5b7b977c67a6d5aa5f42e636410a61c43daa\"},{\"path\":\"SOURCE_REVIEW_PROOF.json\",\"bytes\":3447,\"sha256\":\"7a6b179a873e913e69a86cc6d062606757c84c5c61ff4efdb92c715ae043ac50\"},{\"path\":\"WRAPPER_CHANGE.patch\",\"bytes\":4623,\"sha256\":\"2631e16109d64d08589558154f3754b262ff4f52c29b65dabd2d466b88b77c29\"},{\"path\":\"continue_retirement.py\",\"bytes\":8808,\"sha256\":\"c51db1d2c91d30677cc821813eee60893b735a0515f6de14002ffefb33a5ca24\"},{\"path\":\"leaf_common_endpoint.py\",\"bytes\":47263,\"sha256\":\"616af69135d11abf951e44f243e53b92672acdea97978c7439e0c0fe35dcfaef\"}]},{\"source\":\"/home/ubuntu/otzaria-wave3-library35-executable-source-continuation-20261128\",\"prefix\":\"library-source\",\"files\":[{\"path\":\"EMBEDDED_INPUTS_MANIFEST.json\",\"bytes\":8707,\"sha256\":\"f797c6a7c521fb04c30847c10781dab424aad0e1bd0f8c815771ea02f5eb411a\"},{\"path\":\"INVERSE_PROOF.json\",\"bytes\":3800,\"sha256\":\"7ced681f7ba7cfdd704ce2e1bc524fdb360446e9cee69e776842c6d06ca8d606\"},{\"path\":\"MATERIALIZATION.json\",\"bytes\":2755,\"sha256\":\"bc62854f5700fd4f42a8f564eefd9e4e2a2bea74bc192cb1044afa69f2d1276f\"},{\"path\":\"PLAN.json\",\"bytes\":4172,\"sha256\":\"bdf25d6f6829d0d3826cfde937958231ea1608a8565f3c85b773706d4e9fb7ee\"},{\"path\":\"README.md\",\"bytes\":2654,\"sha256\":\"53921b33b580e14f3c25d3067cf06cb65fe8303f67daa9ef1f81a3d60a7c064b\"},{\"path\":\"RESULT.json\",\"bytes\":2269,\"sha256\":\"0b32ca52ce3bf3a4130bb9e711421a1ad8ae1ca1b7488d0068661075d9b7ffbb\"},{\"path\":\"RUNNER.patch\",\"bytes\":15784,\"sha256\":\"ed4591da9858e7d63a47ab49c793f67917cbd586830ca4d0cd1bb9504676a975\"},{\"path\":\"RUNNER_EDITS.json\",\"bytes\":15020,\"sha256\":\"1ab0e517547f04889bfcaf925205e7a5c28c8270bd68fbe053b6c2a8678beb6d\"},{\"path\":\"SOURCE_PACKET_RAW.zip\",\"bytes\":372080,\"sha256\":\"b2a7eca81fbc957dd1f86718c7b3d735298e4d667b68ec049cedeece456eec2d\"},{\"path\":\"evidence/INITIAL_RESOURCE_ENUMERATION_REFUSAL.json\",\"bytes\":264,\"sha256\":\"99dc2595d5e5def6c3a76029575c44cc5d21ca1fe2625c54685a6c826aace2a1\"},{\"path\":\"evidence/READ_ONLY_SOURCE_JOIN.json\",\"bytes\":51510,\"sha256\":\"b1f87fbe14365a593927c06b26d4662589ff9f70f51b9d151bd5f8539738b582\"},{\"path\":\"evidence/READ_ONLY_SOURCE_JOIN_TRANSPORT.json\",\"bytes\":55,\"sha256\":\"aa1cbc11c3244991858484bec38ad026ec2d11bfea5b3985017265ef37071004\"},{\"path\":\"evidence/read_source_dependencies_corrected.py\",\"bytes\":4662,\"sha256\":\"ad376443ddf00d8464f69d5b376b671d637487802ab37c1fb2a7a1a797d8b926\"},{\"path\":\"evidence/read_source_dependencies_initial.py\",\"bytes\":4557,\"sha256\":\"fe836600056c70797325ef17e6622cb3edae5f90c79f6f7e561fd727f5fa5625\"},{\"path\":\"prepare_source_packet.py\",\"bytes\":29792,\"sha256\":\"944a2503758474d5cd3bedecd4a9fbd82eed0554fbaadcd5ad26bf15255838ba\"},{\"path\":\"prior/CURRENT_MODULE_SOURCE_JOIN.json\",\"bytes\":53158,\"sha256\":\"7768e4896eb3fc6fb2ff2256a820bc03c315b9c512936948c6346164b7a4efef\"},{\"path\":\"prior/ORIGINAL_CAPACITY_REFUSAL.json\",\"bytes\":873,\"sha256\":\"88cd67b319f627715cf123b3b83ca61155614f0270446949064b164b84ec2419\"},{\"path\":\"prior/SERVICE_ATTEMPT2_RESULT.json\",\"bytes\":41059,\"sha256\":\"cbe68cc70ce9ee48130a4eed0347b486ed0cbba5aaffa39ce0ca3c49644d5865\"},{\"path\":\"prior/public-search-portable-runner-attempt-2.py\",\"bytes\":15872,\"sha256\":\"ff27bc9c964c9a86c0869e83f679e105ff773807a73777fc32241f36538c9b0c\"},{\"path\":\"prior/source-owner-attempt-3-runner.py\",\"bytes\":197622,\"sha256\":\"33d2cce7a824beae5b3568e50a1aaa61aa993abfd635a798fb97ee4a1b18d983\"},{\"path\":\"review/LibraryOwnerControls.swift\",\"bytes\":22470,\"sha256\":\"88a845636ba070e023ee3ac4b17133f8ca21f128b0231c3ac344746ccba2623c\"},{\"path\":\"review/MaktabahNativeLibraryListPublication.swift\",\"bytes\":7044,\"sha256\":\"3bcb93f70b9352eeeeb196a41e333da69fc7a9c19e314b4ba1198c2d1c217919\"},{\"path\":\"run_library35.py\",\"bytes\":210052,\"sha256\":\"ed40968e88c43d5633b2820a47d755e0d48030d5c745b53eee0c5e011f7488a5\"},{\"path\":\"seal_source_packet.py\",\"bytes\":8119,\"sha256\":\"767d4e0707e0691f3ac76c505801fa8b31b94e18a55aeb73203b3a4d806715f3\"},{\"path\":\"MANIFEST.json\",\"bytes\":8604,\"sha256\":\"b750f10d1ec85e28926e492ace84e270fdafaf639c398c902b211957cd6a902f\"},{\"path\":\"SOURCE_SEAL.json\",\"bytes\":1926,\"sha256\":\"916fd11ab5325a5591d1658284f45e1d4dc14e5ada766a1780f139e529be981c\"}]}],\"files\":[{\"path\":\"/home/ubuntu/otzaria-wave3-closed-workspaces-nine-relocated-20261128/.relocation-metadata/PREPARED.json\",\"dest\":\"nine-actual/PREPARED.json\",\"bytes\":4861,\"sha256\":\"c0cc1af1aa16a50900f8c31faf5d2c7632aeeee75458af9282cd62d01db6789f\"},{\"path\":\"/home/ubuntu/otzaria-wave3-closed-workspaces-nine-relocated-20261128/.relocation-metadata/CUTOVER_RESULT.json\",\"dest\":\"nine-actual/CUTOVER_RESULT.json\",\"bytes\":68579,\"sha256\":\"dd20d60bc7af6fa77b671b6e3fe7567cae295039b85b33ce266d547bf3f3601f\"},{\"path\":\"/home/ubuntu/otzaria-wave3-preserved-untracked-leaf-transport-20261128/retire-commit-git-endpoint2-20261128/RETIREMENT_RESULT.json\",\"dest\":\"leaf-actual/RETIREMENT_RESULT.json\",\"bytes\":2692,\"sha256\":\"7902f54a0ca77589160a82e44eb9e33209b17a41e23c311883a35773090bbf0b\"},{\"path\":\"/home/ubuntu/otzaria-wave3-preserved-untracked-leaf-transport-20261128/retire-commit-git-endpoint2-20261128/TERMINAL_RESULT.json\",\"dest\":\"leaf-actual/TERMINAL_RESULT.json\",\"bytes\":341,\"sha256\":\"a6d3682a1137d83afbf7b0b98a3b4f8d84921e801d4cae37129559e1157076c0\"},{\"path\":\"/home/ubuntu/otzaria-wave3-preserved-untracked-leaf-transport-20261128/retire-commit-git-endpoint2-20261128/PREUNLINK_REVALIDATED.json\",\"dest\":\"leaf-actual/PREUNLINK_REVALIDATED.json\",\"bytes\":2309,\"sha256\":\"79aadf00454fddc0878158c31052fd518c06940290e158cad4533141289bdd47\"},{\"path\":\"/home/ubuntu/otzaria-wave3-preserved-untracked-leaf-transport-20261128/retire-commit-git-endpoint2-20261128/DURABLE_GIT_READBACK.json\",\"dest\":\"leaf-actual/DURABLE_GIT_READBACK.json\",\"bytes\":5535,\"sha256\":\"7a43978d561d3f1802aca548075d0bf7db5c698e27c5a304fc26e5433e954516\"},{\"path\":\"/home/ubuntu/otzaria-wave3-library-controls-rootfs-20261127/owner-attempt-3/RESULT.json\",\"dest\":\"library-actual/RESULT.json\",\"bytes\":124773,\"sha256\":\"909c6dab027a61f70157547dd155f1b1833613df9390f4a6c2ead389bc447713\"}],\"remoteNative\":{\"completeAssets\":[{\"content_type\":\"application/gzip\",\"created_at\":\"2026-11-28T07:08:59Z\",\"digest\":\"sha256:f427758916a543b58f230c87e3d5eff1067e7db47f79a46d984315f8e155b556\",\"download_count\":0,\"id\":803618998,\"name\":\"native116-remaining-original-evidence-staged-20261128.tar.gz\",\"size\":1272863810,\"state\":\"uploaded\",\"updated_at\":\"2026-11-28T07:13:51Z\",\"url\":\"https://api.github.com/repos/davidpovarsky/Maktabah-preserved-evidence/releases/assets/803618998\"},{\"content_type\":\"application/gzip\",\"created_at\":\"2026-11-28T04:43:44Z\",\"digest\":null,\"download_count\":0,\"id\":803257093,\"name\":\"native116-remaining-original-evidence.tar.gz\",\"size\":1272863810,\"state\":\"starter\",\"updated_at\":\"2026-11-28T04:43:44Z\",\"url\":\"https://api.github.com/repos/davidpovarsky/Maktabah-preserved-evidence/releases/assets/803257093\"},{\"content_type\":\"application/gzip\",\"created_at\":\"2026-11-28T04:42:39Z\",\"digest\":\"sha256:424c2e2f95b3616e39b51cbacc621678dc2899ceba857a2dd42b72b0a0597cc4\",\"download_count\":0,\"id\":803254522,\"name\":\"native116-source-snapshot.json.gz\",\"size\":7106913,\"state\":\"uploaded\",\"updated_at\":\"2026-11-28T04:42:41Z\",\"url\":\"https://api.github.com/repos/davidpovarsky/Maktabah-preserved-evidence/releases/assets/803254522\"},{\"content_type\":\"application/json\",\"created_at\":\"2026-11-28T04:42:42Z\",\"digest\":\"sha256:a8faa73411de67ead8f98856fe25cb3a368d5adb91f1d51f5e3103c9795299c0\",\"download_count\":0,\"id\":803254562,\"name\":\"native116-stream-preservation-manifest.json\",\"size\":160216,\"state\":\"uploaded\",\"updated_at\":\"2026-11-28T04:42:42Z\",\"url\":\"https://api.github.com/repos/davidpovarsky/Maktabah-preserved-evidence/releases/assets/803254562\"}],\"mutations\":0,\"release\":{\"draft\":true,\"id\":461304898,\"tag_name\":\"native116-remaining-stream-20261127-wave3\"},\"repository\":{\"full_name\":\"davidpovarsky/Maktabah-preserved-evidence\",\"id\":1474927804,\"private\":true},\"uploadAttempted\":false,\"utc\":\"2026-11-28T07:16:33.791372+00:00\"}}")
ROOT=pathlib.Path('/home/ubuntu/.codex/worktrees/Maktabah-wave3-integration-rootfs-20261127')
OUT=pathlib.Path('/home/ubuntu/otzaria-wave3-executed-capacity-library-git-representation-20261128')
REL='docs/hq-integration/wave3-executed-capacity-library-20261128'
DEST=ROOT/REL
BEFORE='607bd0a77009ad3495320a96761a60901928f26a'
SOURCE='182dd74229c04959cecae82a59d16268dcbd80bc'
BRANCH='codex/otzaria-wave3-integration-20261127'
FLOOR=1593835520
started=time.monotonic();commands=[]
def need(v,m):
 if not v:raise RuntimeError(m)
def sha(b):return hashlib.sha256(b).hexdigest()
def canon(v):return(json.dumps(v,sort_keys=True,indent=2,ensure_ascii=True)+'\n').encode('ascii')
def free(p='/home/ubuntu'):
 s=os.statvfs(p);return s.f_bavail*s.f_frsize
def stable(s):return(s.st_dev,s.st_ino,s.st_mode,s.st_uid,s.st_gid,s.st_nlink,s.st_size,s.st_mtime_ns,s.st_ctime_ns)
def read(p,pin=None):
 need(p.resolve(strict=True)==p,'Exact canonical input')
 fd=os.open(p,os.O_RDONLY|os.O_NOFOLLOW|os.O_NOATIME)
 try:
  s=os.fstat(fd);need(stat.S_ISREG(s.st_mode) and s.st_nlink==1 and s.st_size<=2097152,'Bounded regular single-link input')
  b=os.pread(fd,2097153,0)
  need(len(b)==s.st_size and stable(os.fstat(fd))==stable(s) and stable(p.lstat())==stable(s),'Stable complete source')
  if pin:need(len(b)==pin['bytes'] and sha(b)==pin['sha256'],'Exact source bytes/hash: '+str(p))
  return b
 finally:os.close(fd)
def guard():
 need(time.monotonic()-started<900,'Publication deadline')
 need(free()>=FLOOR+8388608,'Original Root reserve plus remaining documentation allowance')
def cmd(argv,binary=False):
 guard()
 env=os.environ.copy();env['GIT_OPTIONAL_LOCKS']='0'
 p=subprocess.run(argv,stdin=subprocess.DEVNULL,stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=90,env=env)
 need(len(p.stdout)<=2097152 and len(p.stderr)<=65536,'Bounded command output')
 row={'argv':argv,'exit':p.returncode,'stdoutBytes':len(p.stdout),'stdoutSHA256':sha(p.stdout),'stderrBytes':len(p.stderr),'stderrSHA256':sha(p.stderr)}
 if not binary and len(p.stdout)<=16384:row['stdout']=p.stdout.decode('utf-8','replace')
 if len(p.stderr)<=16384:row['stderr']=p.stderr.decode('utf-8','replace')
 commands.append(row);need(p.returncode==0,'Publication command failed')
 return p.stdout
def git(*args,binary=False):
 return cmd(['sudo','-u','ubuntu','-H','git','-c','gc.auto=0','-c','maintenance.auto=false','-c','core.fsmonitor=false','-c','user.name=ChatGPT','-c','user.email=chatgpt-agent@users.noreply.github.com','-C',str(ROOT),*args],binary)
def api(endpoint):
 return json.loads(cmd(['sudo','-u','ubuntu','-H','gh','api','--hostname','github.com',endpoint],True))
def write(p,b):
 guard();need(len(b)<=2097152,'Bounded documentation leaf')
 stack=[];q=p.parent
 while not q.exists():stack.append(q);q=q.parent
 for d in reversed(stack):
  d.mkdir(mode=0o750);os.chown(d,1001,1001)
 fd=os.open(p,os.O_WRONLY|os.O_CREAT|os.O_EXCL|os.O_NOFOLLOW,0o640)
 try:
  os.fchown(fd,1001,1001);v=memoryview(b)
  while v:
   n=os.write(fd,v);need(n>0,'Complete documentation write');v=v[n:]
  os.fsync(fd)
 finally:os.close(fd)
 fd=os.open(p.parent,os.O_RDONLY|os.O_DIRECTORY|os.O_NOFOLLOW)
 try:os.fsync(fd)
 finally:os.close(fd)
 need(read(p)==b,'Written bytes verified')
def permitted_text_bytes(b,label,depth=0):
 for pat in [rb'gh[pousr]_[A-Za-z0-9_]{30,}',rb'github_pat_[A-Za-z0-9_]{30,}',rb'-----BEGIN (?:RSA |EC |OPENSSH |DSA )?PRIVATE KEY-----',rb'"temp_clone_token"\s*:\s*"[^"]{10,}"']:
  need(re.search(pat,b) is None,'Sensitive literal refused from documentation: '+label)
 if b.startswith(b'PK\x03\x04'):
  need(depth<3,'Bounded nested source archive')
  with zipfile.ZipFile(io.BytesIO(b)) as z:
   need(len(z.infolist())<=2000 and sum(i.file_size for i in z.infolist())<=16777216,'Bounded source archive inspection')
   for i in z.infolist():
    need(not i.filename.startswith('/') and '..' not in pathlib.PurePosixPath(i.filename).parts,'Source archive name')
    if not i.is_dir():permitted_text_bytes(z.read(i),label+'!'+i.filename,depth+1)
need(os.geteuid()==0 and 'GH_DEBUG' not in os.environ and not any(k.startswith('GIT_TRACE') or k=='GIT_CURL_VERBOSE' for k in os.environ),'Non-debug Root executor')
OLD=pathlib.Path('/home/ubuntu/otzaria-wave3-executed-capacity-library-git-intake-20261128')
PRESERVED=OLD/'INITIAL_DOCUMENTATION_BYTES'
need(free()>=FLOOR+16777216,'Original Root reserve plus complete documentation allowance')
need(not os.path.lexists(OUT) and not os.path.lexists(PRESERVED),'Fresh additive continuation')
failed=read(OLD/'FAILED.json',{'bytes':35018,'sha256':'cdb32cace5aab0d43a88a5f0636847268e6e2353bdf3b8126fd49fa20ee9a168'})
need(git('rev-parse','HEAD').decode().strip()==BEFORE and git('branch','--show-current').decode().strip()==BRANCH,'Exact unchanged head/branch')
need(git('rev-parse','HEAD:Source').decode().strip()==SOURCE and git('diff','--name-only','-z')==b'','No unstaged changes')
existing={}
metadata={}
for f in sorted(DEST.rglob('*')):
 if not f.is_file():continue
 n=str(f.relative_to(DEST));b=read(f);existing[n]=b;s=f.lstat()
 metadata[n]={'bytes':len(b),'sha256':sha(b),'uid':s.st_uid,'gid':s.st_gid,'mode':stat.S_IMODE(s.st_mode),'mtimeNS':str(s.st_mtime_ns)}
need(len(existing)==105 and sum(map(len,existing.values()))<=8388608,'Exact first-attempt documentation membership')
names=sorted(REL+'/'+n for n in existing)
need(sorted(x for x in git('diff','--cached','--name-only','-z').decode().split('\0') if x)==names,'Only owned original checkpoint staged')
for n,b in existing.items():need(git('show',':'+REL+'/'+n,binary=True)==b,'Full unchanged initial index bytes')
top_before={x.split(b'\t',1)[1]:x.split(b'\t',1)[0] for x in git('ls-tree','-z','HEAD').split(b'\0') if x}
Out=io.BytesIO()
with zipfile.ZipFile(Out,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
 for n,b in existing.items():
  zi=zipfile.ZipInfo(n,(2026,11,28,0,0,0));zi.create_system=3;zi.external_attr=(stat.S_IFREG|metadata[n]['mode'])<<16;zi.compress_type=zipfile.ZIP_DEFLATED;z.writestr(zi,b)
raw=Out.getvalue();need(len(raw)<=2097152,'Bounded exact archive representation')
with zipfile.ZipFile(io.BytesIO(raw)) as z:
 need(z.testzip() is None and z.namelist()==list(existing),'Full archive CRC/membership')
 for n,b in existing.items():need(z.read(n)==b,'Complete exact archived bytes')
OUT.mkdir(mode=0o750);os.chown(OUT,1001,1001)
try:
 env=os.environ.copy();env['GIT_OPTIONAL_LOCKS']='0'
 check_argv=['sudo','-u','ubuntu','-H','git','-c','gc.auto=0','-c','maintenance.auto=false','-c','core.fsmonitor=false','-C',str(ROOT),'diff','--cached','--check']
 d=subprocess.run(check_argv,stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=30,env=env)
 need(d.returncode==2 and len(d.stdout)==17900 and sha(d.stdout)=='273a16a7ec7aa2db5bebe23ffa2c340d38b9943fbada7a7965aa49a286b9d659' and d.stderr==b'','Exact preserved initial whitespace diagnostic')
 write(OUT/'INITIAL_WHITESPACE_DIAGNOSTIC.txt',d.stdout)
 docs={'EXECUTED_SOURCE_AND_EVIDENCE_RAW.zip':raw,'ORIGINAL_FILES.json':canon({'schema':'otzaria.exact-documentation-archive/1','originalCount':105,'sourcePacketCount':92,'archive':{'name':'EXECUTED_SOURCE_AND_EVIDENCE_RAW.zip','bytes':len(raw),'sha256':sha(raw),'fullCRCAndEveryPayloadReadBack':True},'files':metadata}), 'ACTUAL_SOURCE_CONTROL_SUMMARY.json':existing['ACTUAL_SOURCE_CONTROL_SUMMARY.json'],'NATIVE_POST_TIMEOUT_SAFE_OBSERVATION.json':existing['NATIVE_POST_TIMEOUT_SAFE_OBSERVATION.json'],'INITIAL_WHITESPACE_DIAGNOSTIC.txt':d.stdout,'FIRST_CHECKPOINT_FAILURE.json':failed}
 docs['REPRESENTATION_DECISION.json']=canon({'schema':'otzaria.exact-evidence-representation/1','initialJob':'job_2c6ba5b7cba9','initialFailureSHA256':sha(failed),'initialDiffCheckExit':2,'initialDiagnosticSHA256':sha(d.stdout),'rootDecision':'Preserve all105 exact original artifact bytes in a verified ZIP; retain original full documentation directory privately. Do not normalize archived patches, mutate source, or change any Git whitespace option. The new checked-in text remains subject to unchanged diff--check and normal hooks.','originalDirectoryAfterMove':str(PRESERVED),'onlyRootOwnedStagingRestored':names,'testsRepeated':0,'nonDocsSourceChanged':False,'utc':datetime.datetime.now(datetime.timezone.utc).isoformat()})
 docs['README.md']=b'''# Executed preservation and Library35 controls

EXECUTED_SOURCE_AND_EVIDENCE_RAW.zip contains all105 exact original documentation
files, including all92 files from three closed source packets, actual successful
nine-workspace and leaf-retirement receipts, and the complete Library35 result.
ORIGINAL_FILES.json maps every original member to its byte count and SHA256.
The ZIP received full CRC and individual byte readbacks before publication.

The first documentation staging was refused by the unchanged Git whitespace
check because retained raw patch/ndiff artifacts contain whitespace-significant
context. FIRST_CHECKPOINT_FAILURE.json and INITIAL_WHITESPACE_DIAGNOSTIC.txt
preserve this event. The105 original files remain unchanged in the private
initial documentation directory recorded in REPRESENTATION_DECISION.json.
Their verified archive representation preserves all original bytes. No Git
whitespace setting, hook, source, test or acceptance gate has been weakened.

The archived historical SOURCE_ONLY/NOT_EXECUTED packet declarations remain
exact; the adjacent actual receipts record later executions independently.
Nine original aliases, bytes, metadata and Git identities passed cutover.
The one691303419-byte retained archive was retired only after complete private
readback and the prior607bd0a restoration proof; all84 other entries remain.

Library35 actual source controls:35 PASS/0 FAIL, three expected getter-omission
failures, and expected compile refusal for the invented library enum predicate.
Actual Core/UI/Host source joins and explicit UIKit/diffable/domain/Combine/
workspace boundaries are retained. No healthy module was rebuilt or rerun.

Inspector first execution compiled, then failed with SIGSEGV in an unbounded
Observation fixture before a complete52-case report. Its preserved evidence
and separately reviewed finite-fixture correction remain explicitly separate.

A recorded remote GET observed Native archive803618998 uploaded after the
client timeout, with exact size and digest. Complete authenticated readback and
member verification are still pending at this checkpoint. Original Mac source,
stage and historical starter are retained. This is evidence preservation, not
a new Native116 run. Final SDK/native/production/owner-signature/target merge/
Archive/IPA/TestFlight and physical acceptance remain open.

This commit changes documentation only; Source182dd and every other non-doc
root tree remain identical to607bd0a. Original source-packet CLI files are
historical evidence and must not be blindly rerun after completed operations.
'''
 docs['PUBLISH_REPRESENTATION.py']=pathlib.Path(__file__).read_bytes()
 for n,b in docs.items():permitted_text_bytes(b,n)
 need(sum(map(len,docs.values()))<=4194304,'Bounded continuation documentation payload')
 git('restore','--staged','--',*names)
 need(git('diff','--cached','--name-only','-z')==b'','Owned staging fully restored')
 os.rename(DEST,PRESERVED)
 for p in [DEST.parent,OLD]:
  fd=os.open(p,os.O_RDONLY|os.O_DIRECTORY|os.O_NOFOLLOW);os.fsync(fd);os.close(fd)
 for n,b in existing.items():need(read(PRESERVED/n)==b,'All original artifact bytes preserved after move')
 for n,b in docs.items():write(DEST/n,b)
 final_names=sorted(REL+'/'+n for n in docs)
 git('add','--sparse','-f','--',*final_names)
 need(sorted(x for x in git('diff','--cached','--name-only','-z').decode().split('\0') if x)==final_names,'Only exact archive representation staged')
 git('diff','--cached','--check')
 for n,b in docs.items():need(git('show',':'+REL+'/'+n,binary=True)==b,'Exact final index bytes')
 git('commit','-m','docs: preserve actual capacity and Library35 evidence with exact source archive')
 after=git('rev-parse','HEAD').decode().strip()
 need(git('rev-parse','HEAD^').decode().strip()==BEFORE,'Exact unchanged parent')
 top_after={x.split(b'\t',1)[1]:x.split(b'\t',1)[0] for x in git('ls-tree','-z','HEAD').split(b'\0') if x}
 need(set(top_after)==set(top_before) and all(top_before[k]==top_after[k] for k in top_before if k!=b'docs'),'All non-doc trees exact')
 need(git('status','--porcelain=v1','-z')==b'' and git('rev-parse','HEAD:Source').decode().strip()==SOURCE,'Clean unchanged source')
 git('-c','remote.origin.mirror=false','-c','credential.helper=!gh auth git-credential','push','origin','HEAD:refs/heads/'+BRANCH)
 ref=api('repos/davidpovarsky/Maktabah/git/ref/heads/'+BRANCH)
 need(ref['object']['type']=='commit' and ref['object']['sha']==after,'Exact published branch')
 remote={}
 for n,b in docs.items():
  oid=git('rev-parse',after+':'+REL+'/'+n).decode().strip();v=api('repos/davidpovarsky/Maktabah/git/blobs/'+oid)
  need(v['sha']==oid and v['encoding']=='base64' and v['size']==len(b),'Exact Git blob envelope')
  decoded=base64.b64decode(''.join(v['content'].split()),validate=True)
  need(decoded==b and hashlib.sha1(b'blob '+str(len(b)).encode()+b'\0'+b).hexdigest()==oid,'Complete authenticated remote Git bytes')
  if n=='EXECUTED_SOURCE_AND_EVIDENCE_RAW.zip':
   with zipfile.ZipFile(io.BytesIO(decoded)) as z:
    need(z.testzip() is None and z.namelist()==list(existing),'Remote full archive CRC/membership')
    for member,payload in existing.items():need(z.read(member)==payload,'Remote original artifact bytes exact')
  remote[n]={'path':REL+'/'+n,'bytes':len(b),'sha256':sha(b),'gitBlob':oid}
 proof=canon({'schema':'otzaria.executed-capacity-library-git/2','commit':after,'branch':BRANCH,'source':SOURCE,'files':remote,'all105OriginalArchivePayloadsFullRemoteReadback':True})
 write(OUT/'FULL_REMOTE_READBACK.json',proof);write(OUT/'COMMANDS.json',canon(commands))
 result={'status':'COMMITTED_PUSHED_ALL_FILES_AND105_ORIGINALS_FULL_READBACK','before':BEFORE,'after':after,'sourceUnchanged':SOURCE,'allNonDocsTopTreesUnchanged':True,'fileCount':len(docs),'originalFiles':105,'sourcePacketFiles':92,'archiveBytes':len(raw),'archiveSHA256':sha(raw),'proof':{'path':str(OUT/'FULL_REMOTE_READBACK.json'),'bytes':len(proof),'sha256':sha(proof)},'initialFailurePreserved':True,'originalDirectoryPreserved':str(PRESERVED),'newTestsRun':0,'rootFree':free(),'dataFree':free('/mnt/development'),'utc':datetime.datetime.now(datetime.timezone.utc).isoformat()}
 write(OUT/'RESULT.json',canon(result));print(json.dumps(result))
except BaseException as e:
 write(OUT/'FAILED.json',canon({'errorType':type(e).__name__,'message':str(e),'commands':commands,'utc':datetime.datetime.now(datetime.timezone.utc).isoformat()}));raise
