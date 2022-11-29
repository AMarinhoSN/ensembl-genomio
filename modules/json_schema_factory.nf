// See the NOTICE file distributed with this work for additional information
// regarding copyright ownership.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

process JSON_SCHEMA_FACTORY {
    tag "$manifest_dir.name"
    label 'rc_default'
    // debug true

    input:
    path manifest_dir

    output:
    path "*.json", includeInputs: true

    script:
    // Add quotes around each key of the dictionary to make the list compatible with Bash
    metadata_types = "['" + params.json_schemas.keySet().join("','") + "']"
    """
    json_schema_factory --manifest ${manifest_dir} --metadata_types "${metadata_types}"
    """
}