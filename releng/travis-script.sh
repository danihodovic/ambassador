#!/usr/bin/env bash

# Copyright 2018 Datawire. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License

set -o errexit
set -o nounset

printf "== Begin: travis-script.sh ==\n"

if [[ -n "$TRAVIS_TAG" ]]; then
    if [[ "$TRAVIS_TAG" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        COMMIT_TYPE=GA
    elif [[ "$TRAVIS_TAG" =~ ^v[0-9]+\.[0-9]+\.[0-9]+-rc[0-9]+$ ]]; then
        COMMIT_TYPE=RC
    elif [[ "$TRAVIS_TAG" =~ ^v[0-9]+\.[0-9]+\.[0-9]+-ea[0-9]+$ ]]; then
        COMMIT_TYPE=EA
    else
        echo "TRAVIS_TAG '$TRAVIS_TAG' is not in one of the recognized tag formats:" >&2
        echo " - 'vSEMVER'" >&2
        echo " - 'vSEMVER-rcN'" >&2
        echo " - 'vSEMVER-eaN'" >&2
        echo "Note that the tag name must start with a lowercase 'v'" >&2
        exit 1
    fi
elif [[ "$TRAVIS_PULL_REQUEST" != false ]]; then
    COMMIT_TYPE=PR
else
    COMMIT_TYPE=random
fi

# If downstream, don't re-run release machinery for tags that are an
# existing upstream release.
if [[ "$TRAVIS_REPO_SLUG" != datawire/ambassador ]] &&
   [[ -n "${TRAVIS_TAG:-}" ]] &&
   git fetch https://github.com/datawire/ambassador.git "refs/tags/${TRAVIS_TAG}:refs/upstream-tag" &&
   [[ "$(git rev-parse refs/upstream-tag)" == "$(git rev-parse "refs/tags/${TRAVIS_TAG}")" ]]
then
    COMMIT_TYPE=random
fi
git update-ref -d refs/upstream-tag

printf "========\nCOMMIT_TYPE $COMMIT_TYPE; git status:\n"

git status

printf "========\nSetting up environment...\n"

# case "$COMMIT_TYPE" in
#     GA)
#         eval $(make DOCKER_EXTERNAL_REGISTRY=$DOCKER_REGISTRY export-vars)
#         ;;
#     *)
#         eval $(make USE_KUBERNAUT=true \
#                     DOCKER_EPHEMERAL_REGISTRY=true \
#                     DOCKER_EXTERNAL_REGISTRY=$DOCKER_REGISTRY \
#                     DOCKER_REGISTRY=localhost:31000 \
#                     export-vars)
#         ;;
# esac
set -o xtrace
#make print-vars

printf "========\nStarting build...\n"

case "$COMMIT_TYPE" in
    GA)
        : # We just re-tag the RC image as GA; nothing to build
        ;;
    *)
        # CI might have set DOCKER_BUILD_USERNAME and DOCKER_BUILD_PASSWORD
        # (in case BASE_DOCKER_REPO is private)
       if [[ -n "${DOCKER_BUILD_USERNAME:-}" ]]; then
           docker login -u="$DOCKER_BUILD_USERNAME" --password-stdin "${BASE_DOCKER_REPO%%/*}" <<<"$DOCKER_BUILD_PASSWORD"
       fi

        make test
        ;;
esac

printf "========\nPublishing artifacts...\n"

# case "$COMMIT_TYPE" in
#     GA)
#         if [[ -n "${DOCKER_RELEASE_USERNAME:-}" ]]; then
#             docker login -u="$DOCKER_RELEASE_USERNAME" --password-stdin "${AMBASSADOR_EXTERNAL_DOCKER_REPO%%/*}" <<<"$DOCKER_RELEASE_PASSWORD"
#         fi
#         make release
#         ;;
#     RC)
#         if [[ -n "${DOCKER_RELEASE_USERNAME:-}" ]]; then
#             docker login -u="$DOCKER_RELEASE_USERNAME" --password-stdin "${AMBASSADOR_EXTERNAL_DOCKER_REPO%%/*}" <<<"$DOCKER_RELEASE_PASSWORD"
#         fi
#         make release-rc
#         ;;
#     EA)
#         if [[ -n "${DOCKER_RELEASE_USERNAME:-}" ]]; then
#             docker login -u="$DOCKER_RELEASE_USERNAME" --password-stdin "${AMBASSADOR_EXTERNAL_DOCKER_REPO%%/*}" <<<"$DOCKER_RELEASE_PASSWORD"
#         fi
#         make release-ea
#         ;;
#     *)
#         : # Nothing to do
#         ;;
# esac

printf "== End:   travis-script.sh ==\n"
