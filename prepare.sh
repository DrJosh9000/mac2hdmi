export INSTALL_DIR=~/opt/symbiflow

export FPGA_FAM="xc7"
export PATH="$INSTALL_DIR/$FPGA_FAM/install/bin:$PATH"
source "$INSTALL_DIR/$FPGA_FAM/conda/etc/profile.d/conda.sh"

conda activate $FPGA_FAM
