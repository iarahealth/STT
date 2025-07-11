#!/usr/bin/env python
import glob
import os
import tarfile

import pandas
from iara_stt_training.util.importers import get_importers_parser

COLUMN_NAMES = ["wav_filename", "wav_filesize", "transcript"]


def extract(archive_path, target_dir):
    print("Extracting {} into {}...".format(archive_path, target_dir))
    with tarfile.open(archive_path) as tar:
        tar.extractall(target_dir)


def preprocess_data(tgz_file, target_dir):
    # First extract main archive and sub-archives
    extract(tgz_file, target_dir)
    main_folder = os.path.join(target_dir, "aidatatang_200zh")

    for targz in glob.glob(os.path.join(main_folder, "corpus", "*", "*.tar.gz")):
        extract(targz, os.path.dirname(targz))

    # Folder structure is now:
    # - aidatatang_200zh/
    #   - transcript/aidatatang_200_zh_transcript.txt
    #   - corpus/train/*.tar.gz
    #   - corpus/train/*/*.{wav,txt,trn,metadata}
    #   - corpus/dev/*.tar.gz
    #   - corpus/dev/*/*.{wav,txt,trn,metadata}
    #   - corpus/test/*.tar.gz
    #   - corpus/test/*/*.{wav,txt,trn,metadata}

    # Transcripts file has one line per WAV file, where each line consists of
    # the WAV file name without extension followed by a single space followed
    # by the transcript.

    # Since the transcripts themselves can contain spaces, we split on space but
    # only once, then build a mapping from file name to transcript
    transcripts_path = os.path.join(
        main_folder, "transcript", "aidatatang_200_zh_transcript.txt"
    )
    with open(transcripts_path) as fin:
        transcripts = dict((line.split(" ", maxsplit=1) for line in fin))

    def load_set(glob_path):
        set_files = []
        for wav in glob.glob(glob_path):
            try:
                wav_filename = wav
                wav_filesize = os.path.getsize(wav)
                transcript_key = os.path.splitext(os.path.basename(wav))[0]
                transcript = transcripts[transcript_key].strip("\n")
                set_files.append((wav_filename, wav_filesize, transcript))
            except KeyError:
                print("Warning: Missing transcript for WAV file {}.".format(wav))
        return set_files

    for subset in ("train", "dev", "test"):
        print("Loading {} set samples...".format(subset))
        subset_files = load_set(
            os.path.join(main_folder, "corpus", subset, "*", "*.wav")
        )
        df = pandas.DataFrame(data=subset_files, columns=COLUMN_NAMES)

        # Trim train set to under 10s by removing the last couple hundred samples
        if subset == "train":
            durations = (df["wav_filesize"] - 44) / 16000 / 2
            df = df[durations <= 10.0]
            print("Trimming {} samples > 10 seconds".format((durations > 10.0).sum()))

        dest_csv = os.path.join(target_dir, "aidatatang_{}.csv".format(subset))
        print("Saving {} set into {}...".format(subset, dest_csv))
        df.to_csv(dest_csv, index=False)


def main():
    # https://www.openslr.org/62/
    parser = get_importers_parser(description="Import aidatatang_200zh corpus")
    parser.add_argument("tgz_file", help="Path to aidatatang_200zh.tgz")
    parser.add_argument(
        "--target_dir",
        default="",
        help="Target folder to extract files into and put the resulting CSVs. Defaults to same folder as the main archive.",
    )
    params = parser.parse_args()

    if not params.target_dir:
        params.target_dir = os.path.dirname(params.tgz_file)

    preprocess_data(params.tgz_file, params.target_dir)


if __name__ == "__main__":
    main()
