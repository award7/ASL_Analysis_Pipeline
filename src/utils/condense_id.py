from re import sub


def condense_id(subj_id: str) -> str:
    # use regex to remove any hypens, underscores, or spaces from subject id
    return sub('[-_ ]', '', subj_id)
