BUCKET="gs://deepvariant"
MODEL_VERSION="0.6.0"
MODEL_CL="191676894"

MODEL_NAME="DeepVariant-inception_v3-${MODEL_VERSION}+cl-${MODEL_CL}.data-wgs_standard"
MODEL_BUCKET="${BUCKET}/models/DeepVariant/${MODEL_VERSION}/${MODEL_NAME}"
DATA_BUCKET="${BUCKET}/quickstart-testdata"

WORKSPACE="./quickstart-workspace"
BIN_DIR="./bazel-bin/deepvariant"

mkdir -p "${WORKSPACE}"

echo "downloading the model"
gsutil cp -R "${MODEL_BUCKET}" "${WORKSPACE}"
echo "downloading test data"
gsutil cp -R "${DATA_BUCKET}" "${WORKSPACE}"

OUTPUT_DIR="${WORKSPACE}/output"
mkdir -p "${OUTPUT_DIR}"
REF="${WORKSPACE}/quickstart-testdata/ucsc.hg19.chr20.unittest.fasta"
BAM="${WORKSPACE}/quickstart-testdata/NA12878_S1.chr20.10_10p1mb.bam"
MODEL="${WORKSPACE}/${MODEL_NAME}/model.ckpt"

echo "Running make_examples"

LOGDIR="${WORKSPACE}/logs"
N_SHARDS=3

mkdir -p "${LOGDIR}"
time seq 0 $((N_SHARDS-1)) | \
  parallel --eta --halt 2 --joblog "${LOGDIR}/log" --res "${LOGDIR}" \
  python "${BIN_DIR}/make_examples.zip" \
    --mode calling \
    --ref "${REF}" \
    --reads "${BAM}" \
    --examples "${OUTPUT_DIR}/examples.tfrecord@${N_SHARDS}.gz" \
    --regions '"chr20:10,000,000-10,010,000"' \
    --task {}

echo "Running call_variants"

CALL_VARIANTS_OUTPUT="${OUTPUT_DIR}/call_variants_output.tfrecord.gz"

python "${BIN_DIR}/call_variants.zip" \
 --outfile "${CALL_VARIANTS_OUTPUT}" \
 --examples "${OUTPUT_DIR}/examples.tfrecord@${N_SHARDS}.gz" \
 --checkpoint "${MODEL}"

 echo "Running postprocess_variants"

 FINAL_OUTPUT_VCF="${OUTPUT_DIR}/output.vcf.gz"

python "${BIN_DIR}/postprocess_variants.zip" \
  --ref "${REF}" \
  --infile "${CALL_VARIANTS_OUTPUT}" \
  --outfile "${FINAL_OUTPUT_VCF}"

echo "Done"
