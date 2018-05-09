BUCKET="gs://deepvariant"
MODEL_VERSION="0.6.0"
MODEL_CL="191676894"

MODEL_NAME="DeepVariant-inception_v3-${MODEL_VERSION}+cl-${MODEL_CL}.data-wgs_standard"
MODEL_BUCKET="${BUCKET}/models/DeepVariant/${MODEL_VERSION}/${MODEL_NAME}"
DATA_BUCKET="${BUCKET}/quickstart-testdata"

WORKSPACE="./quickstart-workspace"
mkdir -p "${WORKSPACE}"

echo "downloading the model"
gsutil cp -R "${MODEL_BUCKET}" "${WORKSPACE}"
echo "downloading test data"
gsutil cp -R "${DATA_BUCKET}" "${WORKSPACE}"

OUTPUT_DIR="${WORKSPACE}/output"
mkdir -p "${OUTPUT_DIR}"
REF=quickstart-testdata/ucsc.hg19.chr20.unittest.fasta
BAM=quickstart-testdata/NA12878_S1.chr20.10_10p1mb.bam
MODEL="${WORKSPACE}/${MODEL_NAME}/model.ckpt"

