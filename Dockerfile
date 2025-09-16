2025-09-16T18:36:26.524783361Z ==> Cloning from https://github.com/eapostol/caretwin-auth
2025-09-16T18:36:26.750545874Z ==> Checking out commit d9a851007b4b0867692e6d7c42f7911e1fe4f769 in branch main
2025-09-16T18:36:27.717320982Z #1 [internal] load build definition from Dockerfile
2025-09-16T18:36:27.717349612Z #1 transferring dockerfile: 542B done
2025-09-16T18:36:27.717352583Z #1 DONE 0.0s
2025-09-16T18:36:27.718491554Z Dockerfile:13
2025-09-16T18:36:27.718502194Z --------------------
2025-09-16T18:36:27.718505264Z   11 |     # and bind to $PORT so Render can route traffic.
2025-09-16T18:36:27.718507644Z   12 |     ENTRYPOINT ["/opt/keycloak/bin/kc.sh", "start", 
2025-09-16T18:36:27.718510114Z   13 | >>>   "--http-enabled=true",
2025-09-16T18:36:27.718512244Z   14 |       "--http-port=${PORT}",
2025-09-16T18:36:27.718515084Z   15 |       "--proxy=edge"]
2025-09-16T18:36:27.718517154Z --------------------
2025-09-16T18:36:27.718520194Z error: failed to solve: dockerfile parse error on line 13: unknown instruction: "--http-enabled=true",