"""
Repository rule to manage full wheel version string.

The calculated full version string depends on the wheel type:
- nightly: {version}.dev{build_date}
- release: {version}({custom_version_suffix})?
- custom: {version}.dev{build_date}(+{git_hash})?({custom_version_suffix})?
- snapshot (default): {version}-0

The following environment variables can be set via the build parameters:
{version}: ML_WHEEL_VERSION
{wheel_type}: ML_WHEEL_TYPE
{build_date}: ML_WHEEL_BUILD_DATE
{git_hash}: ML_WHEEL_GIT_HASH
{custom_version_suffix}: ML_WHEEL_VERSION_SUFFIX

Examples:
1. nightly wheel version: 2.19.0.dev20250107
   Build parameters: --repo_env=ML_WHEEL_TYPE=nightly
                     --repo_env=ML_WHEEL_BUILD_DATE=20250107
2. release wheel version: 2.19.0
   Build parameters: --repo_env=ML_WHEEL_TYPE=release
3. release candidate wheel version: 2.19.0-rc1
   Build parameters: --repo_env=ML_WHEEL_TYPE=release
                     --repo_env=ML_WHEEL_VERSION_SUFFIX=-rc1
4. custom wheel version: 2.19.0.dev20250107+cbe478fc5-custom
   Build parameters: --repo_env=ML_WHEEL_TYPE=custom
                     --repo_env=ML_WHEEL_BUILD_DATE=$(git show -s --format=%as HEAD)
                     --repo_env=ML_WHEEL_GIT_HASH=$(git rev-parse HEAD) 
                     --repo_env=ML_WHEEL_CUSTOM_VERSION_SUFFIX=-custom
5. snapshot wheel version: 2.19.0-0
   Build parameters: --repo_env=ML_WHEEL_TYPE=snapshot

"""

load(
    "//third_party/remote_config:common.bzl",
    "get_host_environ",
)

DUMMY_WHEEL_VERSION = "0.0.0"

def _python_wheel_version_repository_impl(repository_ctx):
    wheel_type = get_host_environ(
        repository_ctx,
        _ML_WHEEL_WHEEL_TYPE,
        "snapshot",
    )
    build_date = get_host_environ(repository_ctx, _ML_WHEEL_BUILD_DATE)
    git_hash = get_host_environ(repository_ctx, _ML_WHEEL_GIT_HASH)
    version = get_host_environ(repository_ctx, _ML_WHEEL_VERSION)
    custom_version_suffix = get_host_environ(
        repository_ctx,
        _ML_WHEEL_VERSION_SUFFIX,
    )

    if not version:
        version = DUMMY_WHEEL_VERSION
        print("""
ML_WHEEL_VERSION variable was not set correctly, using dummy version {}.
To set the wheel version, either set ML_WHEEL_VERSION env variable in
your shell:
  export ML_WHEEL_VERSION=2.19.0
OR pass it as an argument to bazel command directly or inside your .bazelrc
file:
  --repo_env=ML_WHEEL_VERSION=2.19.0
""".format(DUMMY_WHEEL_VERSION))  # buildifier: disable=print

    if wheel_type not in ["release", "nightly", "snapshot", "custom"]:
        fail("Environment variable ML_WHEEL_TYPE should have values \"release\", \"nightly\", \"custom\" or \"snapshot\"")

    (major_version, minor_version, patch_version) = version.split(".")

    wheel_version_suffix = ""
    build_tag = ""
    if wheel_type == "nightly":
        if not build_date:
            fail("Environment variable ML_BUILD_DATE is required for nightly builds!")
        formatted_date = build_date.replace("-", "")
        wheel_version_suffix = ".dev{}".format(formatted_date)
    elif wheel_type == "release":
        if custom_version_suffix:
            wheel_version_suffix = custom_version_suffix
    elif wheel_type == "custom":
        if build_date:
            formatted_date = build_date.replace("-", "")
            wheel_version_suffix += ".dev{}".format(formatted_date)
        if git_hash:
            formatted_hash = git_hash[:9]
            wheel_version_suffix += "+{}".format(formatted_hash)
        if custom_version_suffix:
            wheel_version_suffix += custom_version_suffix
    else:
        build_tag = "0"

    semantic_wheel_version_suffix = wheel_version_suffix.replace(".", "-")

    wheel_version_bzl_content = """WHEEL_VERSION = '{wheel_version}'
WHEEL_VERSION_SUFFIX = '{wheel_version_suffix}'
SEMANTIC_WHEEL_VERSION_SUFFIX = '{semantic_wheel_version_suffix}'
BUILD_TAG = '{build_tag}'
MAJOR_VERSION = {major_version}
MINOR_VERSION = {minor_version}
PATCH_VERSION = {patch_version}""".format(
        wheel_version = version,
        wheel_version_suffix = wheel_version_suffix,
        semantic_wheel_version_suffix = semantic_wheel_version_suffix,
        build_tag = build_tag,
        major_version = major_version,
        minor_version = minor_version,
        patch_version = patch_version,
    )

    repository_ctx.file(
        "wheel_version.bzl",
        wheel_version_bzl_content,
    )
    repository_ctx.file("BUILD", "")

_ML_WHEEL_WHEEL_TYPE = "ML_WHEEL_TYPE"
_ML_WHEEL_BUILD_DATE = "ML_WHEEL_BUILD_DATE"
_ML_WHEEL_GIT_HASH = "ML_WHEEL_GIT_HASH"
_ML_WHEEL_VERSION = "ML_WHEEL_VERSION"
_ML_WHEEL_VERSION_SUFFIX = "ML_WHEEL_VERSION_SUFFIX"

_ENVIRONS = [
    _ML_WHEEL_WHEEL_TYPE,
    _ML_WHEEL_BUILD_DATE,
    _ML_WHEEL_GIT_HASH,
    _ML_WHEEL_VERSION,
    _ML_WHEEL_VERSION_SUFFIX,
]

python_wheel_version_repository = repository_rule(
    implementation = _python_wheel_version_repository_impl,
    environ = _ENVIRONS,
)
